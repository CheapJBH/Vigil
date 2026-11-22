<#
.SYNOPSIS
    学生端策略代理：定时从教师端拉取课堂策略并应用。

.DESCRIPTION
    教师端运行 VigilPolicyCenter.ps1 -Serve 后，本机每 2 分钟拉取一次策略：
      GET  <TeacherUrl>/policy   -> 网络白名单 + 保护口令
      POST <TeacherUrl>/report   -> 回报主机名、IP、策略版本、应用结果

    拉到的策略落地到 C:\ProgramData\Vigil\netguard\netguard-policy.json，
    然后调用 VigilNetGuard.ps1 应用；若策略携带 guard 口令哈希，
    同步写入 HKLM\SOFTWARE\VigilGuard 并加固服务。

.PARAMETER TeacherUrl
    教师端策略服务地址，如 http://172.17.202.10:11109
    首次配对时由教师端写入注册表，后续无需再传。

.PARAMETER Install
    注册计划任务（SYSTEM，每 2 分钟），并记录 TeacherUrl。

.PARAMETER Status
    显示上次拉取时间与结果。
#>
[CmdletBinding(DefaultParameterSetName = 'Once')]
param(
    [Parameter(ParameterSetName = 'Install', Mandatory = $true)]
    [string]$TeacherUrl,

    [Parameter(ParameterSetName = 'Install')]
    [switch]$Install,

    [Parameter(ParameterSetName = 'Once')]
    [switch]$Once,

    [Parameter(ParameterSetName = 'Status')]
    [switch]$Status
)

$ErrorActionPreference = 'Stop'
$RegRoot   = 'HKLM:\SOFTWARE\VigilGuard'
$DataDir   = Join-Path $env:ProgramData 'Vigil\netguard'
$LocalJson = Join-Path $DataDir 'netguard-policy.json'
$AuditLog  = Join-Path $DataDir 'agent.log'
$Core      = Join-Path $PSScriptRoot 'VigilNetGuard.ps1'
$TaskName  = 'VigilPolicyAgent'

function Write-Audit([string]$msg) {
    if (-not (Test-Path $DataDir)) { New-Item -ItemType Directory -Force $DataDir | Out-Null }
    $line = '{0} {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg
    Add-Content -LiteralPath $AuditLog -Value $line -Encoding UTF8
}

function Get-TeacherUrl {
    if ($PSBoundParameters.ContainsKey('TeacherUrl') -and $TeacherUrl) { return $TeacherUrl }
    $u = (Get-ItemProperty $RegRoot -ErrorAction SilentlyContinue).TeacherUrl
    if (-not $u) { throw '未配置教师端地址，请先 -Install -TeacherUrl http://<教师机IP>:11109' }
    return $u
}

function Invoke-Sync {
    $base = Get-TeacherUrl
    $base = $base.TrimEnd('/')

    $resp = Invoke-WebRequest -Uri "$base/policy" -UseBasicParsing -TimeoutSec 15
    $json = $resp.Content
    if ([string]::IsNullOrWhiteSpace($json)) { throw '教师端返回空策略' }

    $obj = $json | ConvertFrom-Json
    $version = if ($obj.version) { "$($obj.version)" } else { 'unknown' }

    $changed = $true
    if (Test-Path $LocalJson) {
        $old = Get-Content -LiteralPath $LocalJson -Raw -Encoding UTF8
        if ($old -and ($old.Trim() -eq $json.Trim())) { $changed = $false }
    }

    if ($changed) {
        if (-not (Test-Path $DataDir)) { New-Item -ItemType Directory -Force $DataDir | Out-Null }
        [IO.File]::WriteAllText($LocalJson, $json, (New-Object Text.UTF8Encoding($false)))
        Write-Audit "策略已更新 version=$version"
        & $Core -Policy $LocalJson -SkipDefaultAction | Out-Null
        Write-Audit '策略已应用'
    }

    # 教师端统一下发的保护口令
    if ($obj.guard -and $obj.guard.hash -and $obj.guard.salt) {
        New-Item -Path $RegRoot -Force | Out-Null
        $props    = Get-ItemProperty $RegRoot -ErrorAction SilentlyContinue
        $cur      = $props.Hash
        $released = $props.Released
        # 口令变化，或本机被 -Release 解锁过（覆盖安装/手动解锁），都要重新加固
        if ($cur -ne $obj.guard.hash -or $released -eq 1) {
            Set-ItemProperty $RegRoot -Name Salt       -Value $obj.guard.salt
            Set-ItemProperty $RegRoot -Name Hash       -Value $obj.guard.hash
            Set-ItemProperty $RegRoot -Name Iterations -Value ([int]$obj.guard.iterations)
            if ($cur -ne $obj.guard.hash) { Write-Audit '保护口令已由教师端更新' }
            else { Write-Audit '检测到本地解锁，已重新加固' }
            $guard = Join-Path $PSScriptRoot 'VigilGuard.ps1'
            if (Test-Path $guard) {
                & $guard -Harden | Out-Null
                Remove-ItemProperty $RegRoot -Name Released -ErrorAction SilentlyContinue
            }
        }
    }

    # 回报状态
    try {
        $body = @{
            host    = $env:COMPUTERNAME
            ip      = (Get-NetIPAddress -AddressFamily IPv4 |
                       Where-Object { $_.IPAddress -notlike '127.*' -and $_.PrefixOrigin -ne 'WellKnown' } |
                       Select-Object -First 1 -ExpandProperty IPAddress)
            version = $version
            changed = $changed
            time    = (Get-Date).ToString('s')
        } | ConvertTo-Json -Compress
        Invoke-WebRequest -Uri "$base/report" -Method Post -Body $body `
            -ContentType 'application/json' -UseBasicParsing -TimeoutSec 10 | Out-Null
    } catch {
        Write-Audit "回报失败: $($_.Exception.Message)"
    }
}

switch ($PSCmdlet.ParameterSetName) {

    'Status' {
        Write-Host '== 策略代理状态 ==' -ForegroundColor Cyan
        $u = (Get-ItemProperty $RegRoot -ErrorAction SilentlyContinue).TeacherUrl
        Write-Host "教师端: $(if ($u) { $u } else { '未配置' })"
        $t = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        Write-Host "计划任务: $(if ($t) { $t.State } else { '未安装' })"
        if (Test-Path $LocalJson) {
            $o = Get-Content $LocalJson -Raw | ConvertFrom-Json
            Write-Host "本地策略版本: $($o.version)  模式: $($o.mode)"
        }
        if (Test-Path $AuditLog) {
            Write-Host '--- 最近 10 条 ---'
            Get-Content $AuditLog -Tail 10
        }
    }

    'Install' {
        $id = [Security.Principal.WindowsIdentity]::GetCurrent()
        if (-not (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
                [Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw '安装策略代理需要管理员权限。'
        }
        New-Item -Path $RegRoot -Force | Out-Null
        Set-ItemProperty $RegRoot -Name TeacherUrl -Value $TeacherUrl.TrimEnd('/')

        $action = New-ScheduledTaskAction -Execute 'powershell.exe' `
            -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Once"
        $t1 = New-ScheduledTaskTrigger -AtStartup
        $t2 = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) `
            -RepetitionInterval (New-TimeSpan -Minutes 2) `
            -RepetitionDuration ([TimeSpan]::FromDays(3650))
        $pr = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
        $st = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries `
            -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew
        Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger @($t1, $t2) `
            -Principal $pr -Settings $st -Force | Out-Null

        Write-Host "策略代理已安装：教师端 $TeacherUrl，每 2 分钟同步并开机自启。" -ForegroundColor Green
        Invoke-Sync
    }

    default {
        Invoke-Sync
        Write-Host '策略同步完成。' -ForegroundColor Green
    }
}
