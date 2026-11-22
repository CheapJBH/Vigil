<#
    Vigil 教师端 · 四位数课堂口令
    ------------------------------------------------------------------
    用法：安装完成后从「开始菜单 → Vigil 教师端 → 课堂口令」打开。

    流程：
      1. 确保本机存在课堂认证密钥对 classroom（私钥留在教师机）
      2. 点击「生成新口令」，随机产生 4 位数字
      3. 后台启动配对服务，学生端输入这 4 位数字即可自动完成绑定
      4. 点「停止配对」结束本次课堂
#>

#Requires -Version 5.1

# ---------------------------------------------------------------- 自提升

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    try {
        Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass',
            '-File', "`"$PSCommandPath`""
        )
    } catch {
        [System.Windows.Forms.MessageBox]::Show(
            '需要管理员权限才能配置认证密钥，请右键「以管理员身份运行」。',
            'Vigil 教师端', 'OK', 'Warning') | Out-Null
    }
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = 'Stop'

$Here     = Split-Path -Parent $PSCommandPath
$KeyName  = 'classroom'
$PairPort = 11101
$LogFile  = Join-Path $env:TEMP 'vigil-pair.log'
$ServerPs1 = Join-Path $Here 'VigilPairServer.ps1'

# ---------------------------------------------------------------- 定位 vigil-cli

$Cli = $null
foreach ($candidate in @(
        (Join-Path $Here 'vigil-cli.exe'),
        (Join-Path (Split-Path -Parent $Here) 'vigil-cli.exe'),
        'C:\Program Files\Vigil\vigil-cli.exe',
        'C:\Program Files (x86)\Vigil\vigil-cli.exe')) {
    if (Test-Path $candidate) { $Cli = $candidate; break }
}
if (-not $Cli) {
    [System.Windows.Forms.MessageBox]::Show(
        "找不到 vigil-cli.exe，请重新安装 Vigil 教师端。`n脚本目录：$Here",
        'Vigil 教师端', 'OK', 'Error') | Out-Null
    exit 1
}

# ---------------------------------------------------------------- 辅助

$script:ServerProc = $null

function Invoke-Cli {
    param([string[]]$CliArgs)
    $out = & $Cli @CliArgs 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        throw "vigil-cli $($CliArgs -join ' ') 失败：$out"
    }
    return $out
}

function Initialize-ClassroomKey {
    # 教师端必须用密钥认证，否则后续学生端无法用公钥校验
    $null = Invoke-Cli -CliArgs @('config', 'set', 'Authentication/Method', 'KeyFile')

    $list = Invoke-Cli -CliArgs @('authkeys', 'list')
    if ($list -notmatch [regex]::Escape("$KeyName/private")) {
        $null = Invoke-Cli -CliArgs @('authkeys', 'create', $KeyName)
        return $true
    }
    return $false
}

function Get-LocalAddresses {
    $addrs = @()
    try {
        $addrs = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
            Where-Object {
                $_.IPAddress -match '^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)'
            } |
            Select-Object -ExpandProperty IPAddress
    } catch {
        $addrs = @()
    }
    if (-not $addrs -or $addrs.Count -eq 0) { $addrs = @('（未检测到内网地址）') }
    return $addrs
}

function New-AccessCode {
    return (Get-Random -Minimum 1000 -Maximum 10000).ToString()
}

function Start-PairServer {
    param([string]$AccessCode, [switch]$AutoAccept)

    Stop-PairServer

    if (Test-Path $LogFile) { Remove-Item $LogFile -Force -ErrorAction SilentlyContinue }

    $procArgs = @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass',
        '-File', "`"$ServerPs1`"",
        '-Code', $AccessCode,
        '-Port', $PairPort,
        '-KeyName', $KeyName,
        '-LogFile', "`"$LogFile`""
    )
    if ($AutoAccept) { $procArgs += '-AutoAccept' }

    $script:ServerProc = Start-Process -FilePath 'powershell.exe' `
        -ArgumentList $procArgs -WindowStyle Hidden -PassThru

    Start-Sleep -Milliseconds 800
    if ($script:ServerProc.HasExited) {
        throw "配对服务启动失败（退出码 $($script:ServerProc.ExitCode)），请查看日志。"
    }
}

function Stop-PairServer {
    if ($script:ServerProc -and -not $script:ServerProc.HasExited) {
        try {
            $null = Invoke-WebRequest -Uri "http://127.0.0.1:$PairPort/shutdown" `
                -Method POST -TimeoutSec 2 -UseBasicParsing
        } catch {}
        Start-Sleep -Milliseconds 300
        if (-not $script:ServerProc.HasExited) {
            try { $script:ServerProc.Kill() } catch {}
        }
    }
    $script:ServerProc = $null
}

# ---------------------------------------------------------------- 界面

[System.Windows.Forms.Application]::EnableVisualStyles()

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Vigil 教师端 · 课堂口令'
$form.ClientSize = New-Object System.Drawing.Size(520, 560)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(250, 251, 253)
$form.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9)

$title = New-Object System.Windows.Forms.Label
$title.Text = '课堂口令'
$title.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 15, [System.Drawing.FontStyle]::Bold)
$title.ForeColor = [System.Drawing.Color]::FromArgb(20, 24, 35)
$title.AutoSize = $true
$title.Location = New-Object System.Drawing.Point(28, 22)
$form.Controls.Add($title)

$sub = New-Object System.Windows.Forms.Label
$sub.Text = '让学生在自己电脑上运行「Vigil 学生端 · 绑定课堂」，输入下面 4 位数字即可加入。'
$sub.ForeColor = [System.Drawing.Color]::FromArgb(100, 106, 120)
$sub.AutoSize = $true
$sub.Location = New-Object System.Drawing.Point(30, 60)
$form.Controls.Add($sub)

$codeBox = New-Object System.Windows.Forms.Label
$codeBox.Text = '----'
$codeBox.Font = New-Object System.Drawing.Font('Consolas', 46, [System.Drawing.FontStyle]::Bold)
$codeBox.ForeColor = [System.Drawing.Color]::FromArgb(0, 120, 212)
$codeBox.TextAlign = 'MiddleCenter'
$codeBox.Size = New-Object System.Drawing.Size(464, 96)
$codeBox.Location = New-Object System.Drawing.Point(28, 88)
$codeBox.BackColor = [System.Drawing.Color]::White
$codeBox.BorderStyle = 'FixedSingle'
$form.Controls.Add($codeBox)

function Add-Button {
    param([string]$Text, [int]$X, [int]$Y, [int]$W, [scriptblock]$OnClick)
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $Text
    $b.Size = New-Object System.Drawing.Size($W, 36)
    $b.Location = New-Object System.Drawing.Point($X, $Y)
    $b.FlatStyle = 'Flat'
    $b.FlatAppearance.BorderSize = 1
    $b.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(210, 216, 226)
    $b.BackColor = [System.Drawing.Color]::White
    $b.ForeColor = [System.Drawing.Color]::FromArgb(30, 34, 45)
    $b.Add_Click($OnClick)
    $form.Controls.Add($b)
    return $b
}

$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Multiline = $true
$logBox.ReadOnly = $true
$logBox.ScrollBars = 'Vertical'
$logBox.Size = New-Object System.Drawing.Size(464, 180)
$logBox.Location = New-Object System.Drawing.Point(28, 330)
$logBox.BackColor = [System.Drawing.Color]::White
$logBox.BorderStyle = 'FixedSingle'
$logBox.Font = New-Object System.Drawing.Font('Consolas', 8.5)
$form.Controls.Add($logBox)

$autoCheck = New-Object System.Windows.Forms.CheckBox
$autoCheck.Text = '允许同网段学生端自动加入（免口令）'
$autoCheck.AutoSize = $true
$autoCheck.ForeColor = [System.Drawing.Color]::FromArgb(60, 66, 80)
$autoCheck.Location = New-Object System.Drawing.Point(30, 292)
$autoCheck.Checked = $true   # 默认开启：学生端点「加入课堂」即可绑定

$autoStartCheck = New-Object System.Windows.Forms.CheckBox
$autoStartCheck.Text = '开机自动启动配对服务'
$autoStartCheck.AutoSize = $true
$autoStartCheck.ForeColor = [System.Drawing.Color]::FromArgb(60, 66, 80)
$autoStartCheck.Location = New-Object System.Drawing.Point(300, 292)

# 读取上次选择
try {
    $cfgPath = Join-Path $env:ProgramData 'Vigil\pair-settings.json'
    if (Test-Path $cfgPath) {
        $saved = Get-Content $cfgPath -Raw | ConvertFrom-Json
        if ($null -ne $saved.AutoAccept) { $autoCheck.Checked = [bool]$saved.AutoAccept }
        if ($null -ne $saved.AutoStart) { $autoStartCheck.Checked = [bool]$saved.AutoStart }
    }
} catch {}
$form.Controls.Add($autoCheck)
$form.Controls.Add($autoStartCheck)

function Save-PairSettings {
    try {
        $dir = Join-Path $env:ProgramData 'Vigil'
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        @{
            AutoAccept = [bool]$autoCheck.Checked
            AutoStart  = [bool]$autoStartCheck.Checked
            Code       = if ($codeBox.Text -match '^\d{4}$') { $codeBox.Text } else { '0000' }
        } | ConvertTo-Json | Set-Content -Path (Join-Path $dir 'pair-settings.json') -Encoding UTF8
    } catch {}
}

function Install-TeacherAutoStart {
    param([string]$Code)
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument (
        '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}" -Code {1} -Port {2} -KeyName {3} -LogFile "{4}" {5}' -f `
        $ServerPs1, $Code, $PairPort, $KeyName, $LogFile, $(if ($autoCheck.Checked) { '-AutoAccept' } else { '' }))
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $trigger.Delay = 'PT20S'
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    Register-ScheduledTask -TaskName 'VigilTeacherPair' -Action $action -Trigger $trigger `
        -Principal $principal -Settings $settings -Force | Out-Null
}

function Remove-TeacherAutoStart {
    try { Unregister-ScheduledTask -TaskName 'VigilTeacherPair' -Confirm:$false -ErrorAction Stop } catch {}
}

$script:LastLogSize = 0
function Update-Log {
    if (-not (Test-Path $LogFile)) { return }
    try {
        $fi = Get-Item $LogFile -ErrorAction Stop
        if ($fi.Length -eq $script:LastLogSize) { return }
        $text = Get-Content $LogFile -Raw -ErrorAction Stop
        if ($text -ne $logBox.Text) {
            $logBox.Text = $text
            $logBox.SelectionStart = $logBox.Text.Length
            $logBox.ScrollToCaret()
            $script:LastLogSize = $fi.Length
        }
    } catch {}
}

$btnStart = Add-Button -Text '生成新口令并开始配对' -X 28 -Y 196 -W 220 -OnClick {
    try {
        $btnStart.Enabled = $false
        $created = Initialize-ClassroomKey
        if ($created) { $logBox.AppendText("已创建课堂认证密钥 $KeyName`r`n") }
        $code = New-AccessCode
        $codeBox.Text = $code
        if ($autoStartCheck.Checked) {
            Install-TeacherAutoStart -Code $code
            $logBox.AppendText("已注册开机自启：VigilTeacherPair（口令 $code）`r`n")
        } else {
            Remove-TeacherAutoStart
        }
        Save-PairSettings
        Start-PairServer -AccessCode $code -AutoAccept:$autoCheck.Checked
        Update-Log
        if ($autoCheck.Checked) {
            $logBox.AppendText("免口令模式已开启：同网段学生端会自动加入。`r`n")
        }
        $logBox.AppendText("口令 $code 已生效，等待学生端接入…`r`n")
        $btnStop.Enabled = $true
        $btnCopy.Enabled = $true
        $status.Text = "配对中 · 端口 $PairPort"
        $status.ForeColor = [System.Drawing.Color]::FromArgb(16, 124, 16)
    } catch {
        [System.Windows.Forms.MessageBox]::Show("启动失败：`n$($_.Exception.Message)", 'Vigil 教师端', 'OK', 'Error') | Out-Null
        $btnStart.Enabled = $true
    }
}

$btnStop = Add-Button -Text '停止配对' -X 256 -Y 196 -W 110 -OnClick {
    Stop-PairServer
    $codeBox.Text = '----'
    $btnStart.Enabled = $true
    $btnStop.Enabled = $false
    $btnCopy.Enabled = $false
    $status.Text = '已停止'
    $status.ForeColor = [System.Drawing.Color]::FromArgb(100, 106, 120)
    $logBox.AppendText('配对服务已停止。' + "`r`n")
}
$btnStop.Enabled = $false

$btnCopy = Add-Button -Text '复制口令' -X 374 -Y 196 -W 118 -OnClick {
    if ($codeBox.Text -match '^\d{4}$') {
        [System.Windows.Forms.Clipboard]::SetText($codeBox.Text)
        $logBox.AppendText('口令已复制到剪贴板。' + "`r`n")
    }
}
$btnCopy.Enabled = $false

$status = New-Object System.Windows.Forms.Label
$status.Text = '未启动'
$status.ForeColor = [System.Drawing.Color]::FromArgb(100, 106, 120)
$status.AutoSize = $true
$status.Location = New-Object System.Drawing.Point(30, 242)
$form.Controls.Add($status)

$netLabel = New-Object System.Windows.Forms.Label
$netLabel.Text = '本机地址：' + ((Get-LocalAddresses) -join '  /  ')
$netLabel.ForeColor = [System.Drawing.Color]::FromArgb(100, 106, 120)
$netLabel.AutoSize = $true
$netLabel.Location = New-Object System.Drawing.Point(30, 266)
$form.Controls.Add($netLabel)

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1000
$timer.Add_Tick({ Update-Log })
$timer.Start()

$form.Add_FormClosing({
    $timer.Stop()
    Stop-PairServer
})

$logBox.AppendText("就绪。密钥 $KeyName，配对端口 $PairPort。`r`n")
$logBox.AppendText('点击「生成新口令并开始配对」后，把显示的 4 位数字告诉学生。' + "`r`n")

[void]$form.ShowDialog()
