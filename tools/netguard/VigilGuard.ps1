<#
.SYNOPSIS
    Vigil Guard：让学生机上的管控服务与守护任务无法被随手停止，
    正常停用必须输入教师设定的口令。

.DESCRIPTION
    三层防护，全部使用 Windows 原生机制，不加载驱动：

    1. 服务权限收紧（SCM SDDL）
       从 Administrators 的 ACE 中移除 SERVICE_STOP / SERVICE_CHANGE_CONFIG /
       SERVICE_PAUSE_CONTINUE。之后 `net stop`、`sc stop`、服务管理器里的
       "停止"按钮都会返回拒绝访问。

    2. 服务失败自动恢复
       `sc failure` 配置为 "崩溃/被杀 -> 1 秒后重启"，配合 failureflag，
       即使有人直接 taskkill 进程，SCM 也会立刻把它拉回来。

    3. 随机化守护任务 + 口令解锁
       守护计划任务放在 \Microsoft\Windows\Application Experience\ 下，
       名称由本机 MachineGuid 派生，不出现在常规任务列表里显眼位置。
       `-Release` 需要教师口令（PBKDF2-SHA256 存储）。

    诚实说明：拥有本地管理员权限的人仍然可以通过取得所有权、
    修改 DACL、加载驱动等方式绕过。本工具的目标是"随手关不掉"，
    不是"内核级不可杀"——后者需要 PPL 驱动签名，不在本方案范围。

.PARAMETER Install
    首次部署：设置口令并加固。

.PARAMETER Password
    教师口令（明文，仅用于本次计算哈希，不落盘）。

.PARAMETER Harden
    只做加固（口令已设置过时使用）。

.PARAMETER Release
    解除加固，恢复管理员可停止权限。

.PARAMETER Status
    显示当前加固状态。

.PARAMETER ServiceName
    默认 VigilService。

.EXAMPLE
    .\VigilGuard.ps1 -Install -Password 'Jiaoshi2026'

.EXAMPLE
    .\VigilGuard.ps1 -Release -Password 'Jiaoshi2026'
#>
[CmdletBinding(DefaultParameterSetName = 'Status')]
param(
    [Parameter(ParameterSetName = 'Install', Mandatory = $true)]
    [switch]$Install,

    [Parameter(ParameterSetName = 'Install', Mandatory = $true)]
    [Parameter(ParameterSetName = 'Release', Mandatory = $true)]
    [Parameter(ParameterSetName = 'SetPassword', Mandatory = $true)]
    [string]$Password,

    [Parameter(ParameterSetName = 'Harden')]
    [switch]$Harden,

    [Parameter(ParameterSetName = 'Release')]
    [switch]$Release,

    [Parameter(ParameterSetName = 'SetPassword')]
    [switch]$SetPassword,

    [Parameter(ParameterSetName = 'Status')]
    [switch]$Status,

    [string]$ServiceName = 'VigilService',

    # 受保护的程序目录，默认自动推断（注册表 InstallDir 或脚本上级目录）
    [string]$GuardDir
)

$ErrorActionPreference = 'Stop'
$script:ParamSet = $PSCmdlet.ParameterSetName

$RegRoot     = 'HKLM:\SOFTWARE\VigilGuard'
$TaskFolder  = '\Microsoft\Windows\Application Experience\'
$GroupName   = 'Vigil NetGuard'

# ---------------------------------------------------------------- 基础工具

function Assert-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
            [Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host '需要管理员权限，正在提升...' -ForegroundColor Yellow
        $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
        switch ($script:ParamSet) {
            'Install'     { $argList += @('-Install', '-Password', "`"$Password`"") }
            'Release'     { $argList += @('-Release', '-Password', "`"$Password`"") }
            'SetPassword' { $argList += @('-SetPassword', '-Password', "`"$Password`"") }
            'Harden'      { $argList += '-Harden' }
        }
        Start-Process -FilePath (Get-Process -Id $PID).Path -Verb RunAs -ArgumentList $argList
        exit
    }
}

function New-PasswordRecord([string]$Plain) {
    $salt = New-Object byte[] 16
    $rng  = [Security.Cryptography.RandomNumberGenerator]::Create()
    $rng.GetBytes($salt); $rng.Dispose()
    $kdf  = New-Object Security.Cryptography.Rfc2898DeriveBytes(
        $Plain, $salt, 120000,
        [Security.Cryptography.HashAlgorithmName]::SHA256)
    $hash = $kdf.GetBytes(32); $kdf.Dispose()
    @{
        salt = [Convert]::ToBase64String($salt)
        hash = [Convert]::ToBase64String($hash)
        iter = 120000
    }
}

function Test-Password([string]$Plain) {
    if (-not (Test-Path $RegRoot)) { throw '尚未设置口令（VigilGuard 未安装）。' }
    $rec  = Get-ItemProperty $RegRoot
    $salt = [Convert]::FromBase64String($rec.Salt)
    $want = [Convert]::FromBase64String($rec.Hash)
    $kdf  = New-Object Security.Cryptography.Rfc2898DeriveBytes(
        $Plain, $salt, [int]$rec.Iterations,
        [Security.Cryptography.HashAlgorithmName]::SHA256)
    $got = $kdf.GetBytes($want.Length); $kdf.Dispose()
    $diff = 0
    for ($i = 0; $i -lt $got.Length; $i++) { $diff = $diff -bor ($got[$i] -bxor $want[$i]) }
    return ($diff -eq 0)
}

function Get-GuardTaskName {
    $name = $null
    if (Test-Path $RegRoot) { $name = (Get-ItemProperty $RegRoot).TaskName }
    if (-not $name) {
        # 由 MachineGuid 派生：每台机器不同、可复现、不显眼
        $guid = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Cryptography' -Name MachineGuid).MachineGuid
        $sha  = [Security.Cryptography.SHA256]::Create()
        $b    = $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes("vigil-guard:$guid"))
        $sha.Dispose()
        $name = -join ($b[0..3] | ForEach-Object { $_.ToString('x2') })
        $name = "Application Experience $name"
    }
    return $name
}

# ---------------------------------------------------------------- 加固

function Set-ServiceStopProtection {
    param([string]$Name)

    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if (-not $svc) {
        Write-Host "  $Name : 服务不存在，跳过服务加固（仅保护文件）" -ForegroundColor Yellow
        return
    }

    # 崩溃 / 被强杀后自动拉起
    & sc.exe failure $Name reset= 0 actions= restart/1000/restart/1000/restart/1000 | Out-Null
    & sc.exe failureflag $Name 1 | Out-Null

    # SCM 安全描述符：管理员保留查询/启动/读状态，但移除停止与改配置
    # BA 保留 RP(启动)/WD(改权限,便于 -Release 自救)，移除 WP(停止)/DC(改配置)/DT(暂停)
    $sddl = 'D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCLCSWRPLOCRRCWD;;;BA)' +
            '(A;;CCLCSWLOCRRC;;;IU)(A;;CCLCSWLOCRRC;;;SU)'
    $out = & sc.exe sdset $Name $sddl 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "设置服务权限失败: $out"
    } else {
        Write-Host "  $Name : 已禁止管理员停止（保留查询与启动）" -ForegroundColor Green
    }
}

function Set-ServiceStopOpen {
    param([string]$Name)
    $sddl = 'D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)' +
            '(A;;CCLCSWLOCRRC;;;IU)(A;;CCLCSWLOCRRC;;;SU)'
    & sc.exe sdset $Name $sddl 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  $Name : 已恢复管理员停止权限" -ForegroundColor Yellow
    } else {
        Write-Warning "恢复服务权限失败，可能需要 takeown 后重试"
    }
}

function Set-ServiceAutoStart {
    param([string]$Name)
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if (-not $svc) { return }
    if ($svc.StartType -ne 'Automatic') {
        & sc.exe config $Name start= auto | Out-Null
    }
    # 依赖网络栈，确保开机时网卡已就绪
    & sc.exe config $Name depend= Tcpip/Afd | Out-Null
    Write-Host "  $Name : 启动类型 Automatic，开机自启" -ForegroundColor Green
}

# ---------------------------------------------------------------- 文件保护

function Get-InstallDir {
    if ($GuardDir -and (Test-Path $GuardDir)) { return (Resolve-Path $GuardDir).Path }
    if (Test-Path $RegRoot) {
        $d = (Get-ItemProperty $RegRoot -Name InstallDir -ErrorAction SilentlyContinue).InstallDir
        if ($d -and (Test-Path $d)) { return $d }
    }
    return (Split-Path $PSScriptRoot -Parent)
}

function Test-FileProtection {
    param([string]$Dir)
    if (-not (Test-Path $Dir)) { return $false }
    try { $acl = Get-Acl -LiteralPath $Dir } catch { return $false }
    $deny = $acl.Access | Where-Object {
        $_.AccessControlType -eq 'Deny' -and
        ($_.IdentityReference.Value -match 'S-1-5-32-544|Administrators') -and
        (($_.FileSystemRights -band [Security.AccessControl.FileSystemRights]::Delete) -ne 0)
    }
    return [bool]$deny
}

function Set-FileProtection {
    param([string]$Dir)
    if (-not (Test-Path $Dir)) { Write-Warning "安装目录不存在: $Dir"; return }

    $sidSystem = '*S-1-5-18'
    $sidAdmins = '*S-1-5-32-544'
    $sidUsers  = '*S-1-5-32-545'

    # 断开继承，重建精简 DACL：SYSTEM/管理员完全控制，普通用户只读运行
    & icacls.exe $Dir /inheritance:r | Out-Null
    & icacls.exe $Dir /grant:r "${sidSystem}:(OI)(CI)F" "${sidAdmins}:(OI)(CI)F" "${sidUsers}:(OI)(CI)RX" | Out-Null

    # Deny 优先于 Allow：即使管理员也无法删除目录本身和其中的文件
    $out = & icacls.exe $Dir /deny "${sidAdmins}:(OI)(CI)(DE,DC)" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "文件保护设置失败: $out"
        return
    }
    Write-Host "  文件保护: $Dir（管理员不可删除，需口令解锁）" -ForegroundColor Green
}

function Set-FileProtectionOpen {
    param([string]$Dir)
    if (-not (Test-Path $Dir)) { return }
    # /T 递归移除继承下来的 Deny，再恢复继承
    & icacls.exe $Dir /remove:d '*S-1-5-32-544' /T /C | Out-Null
    & icacls.exe $Dir /inheritance:e /T /C | Out-Null
    if (Test-FileProtection $Dir) {
        Write-Warning "文件保护未完全解除，请手动检查: $Dir"
    } else {
        Write-Host "  文件保护已解除: $Dir" -ForegroundColor Yellow
    }
}

function Install-GuardTask {
    $taskName = Get-GuardTaskName
    $core     = Join-Path $PSScriptRoot 'VigilNetGuard.ps1'
    $daemon   = Join-Path $PSScriptRoot 'VigilNetGuardDaemon.ps1'
    if (-not (Test-Path $core)) { $core = 'C:\ProgramData\Vigil\netguard\VigilNetGuard.ps1' }

    $script = Join-Path $env:ProgramData 'Vigil\netguard\guard-runner.ps1'
    New-Item -ItemType Directory -Force (Split-Path $script) | Out-Null
    @"
`$ErrorActionPreference = 'SilentlyContinue'
# 1) 保持管控服务启动类型与运行状态
`$svc = Get-Service -Name '$ServiceName'
if (`$svc) {
    if (`$svc.StartType -ne 'Automatic') { & sc.exe config '$ServiceName' start= auto | Out-Null }
    if (`$svc.Status -ne 'Running') { Start-Service -Name '$ServiceName' }
}
# 2) 补回防火墙规则
if (Test-Path '$daemon') { & '$daemon' -Once }
"@ | Set-Content -LiteralPath $script -Encoding UTF8

    $action = New-ScheduledTaskAction -Execute 'powershell.exe' `
        -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$script`""
    $t1 = New-ScheduledTaskTrigger -AtStartup
    $t2 = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(2) `
        -RepetitionInterval (New-TimeSpan -Minutes 2) `
        -RepetitionDuration ([TimeSpan]::FromDays(3650))
    $pr = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $st = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew

    Register-ScheduledTask -TaskName $taskName -TaskPath $TaskFolder `
        -Action $action -Trigger @($t1, $t2) -Principal $pr -Settings $st -Force | Out-Null

    # 任务本身也设为隐藏、不可被普通用户改
    $t = Get-ScheduledTask -TaskName $taskName -TaskPath $TaskFolder -ErrorAction SilentlyContinue
    if ($t) {
        try {
            $t.Settings.Hidden = $true
            Set-ScheduledTask -TaskName $taskName -TaskPath $TaskFolder -Settings $t.Settings | Out-Null
        } catch {
            Write-Warning "设置隐藏标志失败（任务仍有效）: $($_.Exception.Message)"
        }
    } else {
        Write-Warning "任务已注册但无法查询到（隐藏标志跳过）: $TaskFolder$taskName"
    }

    if (-not (Test-Path $RegRoot)) { New-Item -Path $RegRoot -Force | Out-Null }
    Set-ItemProperty $RegRoot -Name TaskName -Value $taskName
    Write-Host "  守护任务: $TaskFolder$taskName（隐藏，SYSTEM，每 2 分钟）" -ForegroundColor Green
    return $taskName
}

function Remove-GuardTask {
    $taskName = Get-GuardTaskName
    Unregister-ScheduledTask -TaskName $taskName -TaskPath $TaskFolder -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host '  守护任务已移除'
}

# ---------------------------------------------------------------- 入口

switch ($script:ParamSet) {

    'Status' {
        Write-Host '== Vigil Guard 状态 ==' -ForegroundColor Cyan
        $svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if ($svc) {
            Write-Host "服务 $ServiceName : $($svc.Status) / 启动类型 $($svc.StartType)"
        } else {
            Write-Host "服务 $ServiceName : 未安装"
        }
        $q = & sc.exe sdshow $ServiceName 2>$null
        if ($q) {
            if ($q -match 'BA\)' -and $q -match 'CCLCSWRPWPDTLOCRRC;;;BA') {
                Write-Host '服务权限: 未加固（管理员可停止）' -ForegroundColor Yellow
            } else {
                Write-Host '服务权限: 已加固（管理员不可停止）' -ForegroundColor Green
            }
        }
        $taskName = Get-GuardTaskName
        $t = Get-ScheduledTask -TaskName $taskName -TaskPath $TaskFolder -ErrorAction SilentlyContinue
        Write-Host "守护任务: $(if ($t) { "$($t.State) ($TaskFolder$taskName)" } else { '未安装' })"
        Write-Host "口令: $(if (Test-Path $RegRoot) { '已设置' } else { '未设置' })"
        $dir = Get-InstallDir
        if (Test-FileProtection $dir) {
            Write-Host "文件保护: 已启用（管理员不可删除: $dir）" -ForegroundColor Green
        } else {
            Write-Host "文件保护: 未启用（$dir）" -ForegroundColor Yellow
        }
    }

    'Install' {
        Assert-Admin
        New-Item -Path $RegRoot -Force | Out-Null
        Set-ServiceStopOpen -Name $ServiceName
        $rec = New-PasswordRecord $Password
        Set-ItemProperty $RegRoot -Name Salt  -Value $rec.salt
        Set-ItemProperty $RegRoot -Name Hash  -Value $rec.hash
        Set-ItemProperty $RegRoot -Name Iterations -Value $rec.iter
        Write-Host '口令已保存。' -ForegroundColor Green

        $taskName = Install-GuardTask
        Set-ItemProperty $RegRoot -Name TaskName -Value $taskName

        Set-ServiceAutoStart -Name $ServiceName
        Set-ServiceStopProtection -Name $ServiceName

        $dir = Get-InstallDir
        Set-ItemProperty $RegRoot -Name InstallDir -Value $dir
        Set-FileProtection -Dir $dir

        Write-Host 'Vigil Guard 部署完成。' -ForegroundColor Green
    }

    'Harden' {
        Assert-Admin
        Set-ServiceStopOpen -Name $ServiceName
        Set-ServiceAutoStart -Name $ServiceName
        Set-ServiceStopProtection -Name $ServiceName
        Install-GuardTask | Out-Null

        $dir = Get-InstallDir
        if (-not (Test-Path $RegRoot)) { New-Item -Path $RegRoot -Force | Out-Null }
        Set-ItemProperty $RegRoot -Name InstallDir -Value $dir
        Set-FileProtection -Dir $dir

        Write-Host '加固完成。' -ForegroundColor Green
    }

    'SetPassword' {
        Assert-Admin
        New-Item -Path $RegRoot -Force | Out-Null
        $rec = New-PasswordRecord $Password
        Set-ItemProperty $RegRoot -Name Salt  -Value $rec.salt
        Set-ItemProperty $RegRoot -Name Hash  -Value $rec.hash
        Set-ItemProperty $RegRoot -Name Iterations -Value $rec.iter
        Write-Host '口令已更新。' -ForegroundColor Green
    }

    'Release' {
        Assert-Admin
        $ok = $false
        try { $ok = Test-Password $Password } catch { Write-Host $_.Exception.Message -ForegroundColor Red }
        if (-not $ok) {
            Write-Host '口令错误，拒绝解除。' -ForegroundColor Red
            exit 1
        }

        # 先放开文件权限，否则卸载程序/覆盖安装无法删除程序目录
        Set-FileProtectionOpen -Dir (Get-InstallDir)
        Remove-GuardTask
        Set-ServiceStopOpen -Name $ServiceName
        if (Test-Path $RegRoot) { Set-ItemProperty $RegRoot -Name Released -Value 1 -Type DWord }
        Write-Host '已解除保护，现在可以正常卸载或停止服务。' -ForegroundColor Green
    }
}
