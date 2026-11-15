<#
    Vigil 学生端 · 绑定课堂
    ------------------------------------------------------------------
    用法：安装完成后从「开始菜单 → Vigil 学生端 → 绑定课堂」打开。

    流程：
      1. 输入老师屏幕上的 4 位数字
      2. 程序自动扫描本网段（也可手动填教师机 IP）
      3. 找到教师端后取回课堂公钥，写入本机认证密钥目录
      4. 重启 Vigil 服务，之后教师端即可连接本机

    说明：公钥只用于验证教师端身份，不包含任何可逆向出私钥的信息。
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
            '需要管理员权限才能写入认证密钥，请右键「以管理员身份运行」。',
            'Vigil 学生端', 'OK', 'Warning') | Out-Null
    }
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = 'Stop'

$Here      = Split-Path -Parent $PSCommandPath
$KeyName   = 'classroom'
$PairPort  = 11101
$ServiceName = 'VigilService'
$ConnectMs = 700

# ---------------------------------------------------------------- 定位 vigil-cli

$Cli = $null
foreach ($candidate in @(
        (Join-Path $Here 'vigil-cli.exe'),
        (Join-Path (Split-Path -Parent $Here) 'vigil-cli.exe'),
        'C:\Program Files\Vigil\vigil-cli.exe',
        'C:\Program Files (x86)\Vigil\vigil-cli.exe')) {
    if (Test-Path $candidate) { $Cli = $candidate; break }
}

# ---------------------------------------------------------------- 网络工具

function Get-ScanTargets {
    $targets = New-Object System.Collections.Generic.List[string]
    try {
        $locals = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
            Where-Object { $_.IPAddress -match '^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)' }
        foreach ($a in $locals) {
            $parts = $a.IPAddress.Split('.')
            $prefix = "$($parts[0]).$($parts[1]).$($parts[2])"
            for ($i = 1; $i -le 254; $i++) {
                $targets.Add("$prefix.$i")
            }
        }
    } catch {}

    $unique = @($targets | Select-Object -Unique)
    if ($unique.Count -eq 0) {
        # 兜底：教室常用网段
        $list = New-Object System.Collections.Generic.List[string]
        for ($i = 1; $i -le 254; $i++) { $list.Add("172.17.202.$i") }
        return $list.ToArray()
    }
    return $unique
}

function Test-PortBatch {
    param([string[]]$Addresses, [int]$Port, [int]$TimeoutMs = 700)

    $pending = @{}
    foreach ($ip in $Addresses) {
        $client = $null
        try {
            $client = New-Object System.Net.Sockets.TcpClient
            $client.NoDelay = $true
            $null = $client.BeginConnect($ip, $Port, $null, $null)
            $pending[$ip] = $client
        } catch {
            if ($client) { try { $client.Close() } catch {} }
        }
    }

    Start-Sleep -Milliseconds $TimeoutMs

    $alive = New-Object System.Collections.Generic.List[string]
    foreach ($ip in $pending.Keys) {
        $c = $pending[$ip]
        try {
            if ($c.Connected) {
                $alive.Add($ip)
            }
        } catch {
        } finally {
            try { $c.Close() } catch {}
        }
    }
    return $alive.ToArray()
}

function Invoke-PairRequest {
    param([string]$Ip, [string]$Code)

    $hostName = [System.Uri]::EscapeDataString([string]$env:COMPUTERNAME)
    $url = "http://${Ip}:$PairPort/pair?code=$Code&name=$hostName"
    try {
        $resp = Invoke-WebRequest -Uri $url -TimeoutSec 4 -UseBasicParsing -ErrorAction Stop
        $body = $resp.Content
        if ($body -match 'BEGIN PUBLIC KEY') { return $body }
        return $null
    } catch {
        return $null
    }
}

function Test-TeacherAlive {
    param([string]$Ip)
    try {
        $resp = Invoke-WebRequest -Uri "http://${Ip}:$PairPort/ping" -TimeoutSec 2 -UseBasicParsing -ErrorAction Stop
        return ($resp.Content -like 'vigil-teacher*')
    } catch {
        return $false
    }
}

function Import-PublicKey {
    param([string]$Pem)

    $tmp = Join-Path $env:TEMP ("vigil-pub-in-{0}.pem" -f $PID)
    try {
        Set-Content -Path $tmp -Value $Pem -Encoding ASCII -NoNewline
        $out = & $Cli authkeys import "$KeyName/public" $tmp 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0 -and $out -notmatch 'already exists') {
            # 已存在时先删再导入，保证口令轮换后仍能更新
            $null = & $Cli authkeys delete "$KeyName/public" 2>&1
            $out = & $Cli authkeys import "$KeyName/public" $tmp 2>&1 | Out-String
            if ($LASTEXITCODE -ne 0) { throw $out.Trim() }
        }
        return $true
    } finally {
        if (Test-Path $tmp) { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
    }
}

function Restart-VigilService {
    try {
        $svc = Get-Service -Name $ServiceName -ErrorAction Stop
        if ($svc.Status -eq 'Running') {
            Restart-Service -Name $ServiceName -Force -ErrorAction Stop
        } else {
            Start-Service -Name $ServiceName -ErrorAction Stop
        }
        Start-Sleep -Milliseconds 500
        return (Get-Service -Name $ServiceName).Status -eq 'Running'
    } catch {
        return $false
    }
}

# ---------------------------------------------------------------- 界面

[System.Windows.Forms.Application]::EnableVisualStyles()

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Vigil 学生端 · 绑定课堂'
$form.ClientSize = New-Object System.Drawing.Size(460, 400)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(250, 251, 253)
$form.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9)

$title = New-Object System.Windows.Forms.Label
$title.Text = '输入课堂口令'
$title.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 15, [System.Drawing.FontStyle]::Bold)
$title.ForeColor = [System.Drawing.Color]::FromArgb(20, 24, 35)
$title.AutoSize = $true
$title.Location = New-Object System.Drawing.Point(28, 22)
$form.Controls.Add($title)

$sub = New-Object System.Windows.Forms.Label
$sub.Text = '请输入老师屏幕上显示的 4 位数字。'
$sub.ForeColor = [System.Drawing.Color]::FromArgb(100, 106, 120)
$sub.AutoSize = $true
$sub.Location = New-Object System.Drawing.Point(30, 60)
$form.Controls.Add($sub)

$codeInput = New-Object System.Windows.Forms.TextBox
$codeInput.Font = New-Object System.Drawing.Font('Consolas', 34, [System.Drawing.FontStyle]::Bold)
$codeInput.TextAlign = 'Center'
$codeInput.MaxLength = 4
$codeInput.Size = New-Object System.Drawing.Size(180, 66)
$codeInput.Location = New-Object System.Drawing.Point(28, 90)
$codeInput.BackColor = [System.Drawing.Color]::White
$codeInput.ForeColor = [System.Drawing.Color]::FromArgb(0, 120, 212)
$form.Controls.Add($codeInput)

$codeInput.Add_KeyPress({
    param($sender, $e)
    if ($e.KeyChar -notmatch '[\d]' -and $e.KeyChar -ne [char]8) { $e.Handled = $true }
})

$ipLabel = New-Object System.Windows.Forms.Label
$ipLabel.Text = '教师机 IP（可留空，自动扫描本网段）'
$ipLabel.ForeColor = [System.Drawing.Color]::FromArgb(100, 106, 120)
$ipLabel.AutoSize = $true
$ipLabel.Location = New-Object System.Drawing.Point(230, 96)
$form.Controls.Add($ipLabel)

$ipInput = New-Object System.Windows.Forms.TextBox
$ipInput.Font = New-Object System.Drawing.Font('Consolas', 11)
$ipInput.Size = New-Object System.Drawing.Size(200, 26)
$ipInput.Location = New-Object System.Drawing.Point(230, 120)
$ipInput.BackColor = [System.Drawing.Color]::White
$form.Controls.Add($ipInput)

function Add-Button {
    param([string]$Text, [int]$X, [int]$Y, [int]$W, [scriptblock]$OnClick)
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $Text
    $b.Size = New-Object System.Drawing.Size($W, 38)
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

$status = New-Object System.Windows.Forms.Label
$status.Text = '准备就绪'
$status.ForeColor = [System.Drawing.Color]::FromArgb(100, 106, 120)
$status.AutoSize = $true
$status.Location = New-Object System.Drawing.Point(30, 168)
$form.Controls.Add($status)

$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Multiline = $true
$logBox.ReadOnly = $true
$logBox.ScrollBars = 'Vertical'
$logBox.Size = New-Object System.Drawing.Size(404, 150)
$logBox.Location = New-Object System.Drawing.Point(28, 196)
$logBox.BackColor = [System.Drawing.Color]::White
$logBox.BorderStyle = 'FixedSingle'
$logBox.Font = New-Object System.Drawing.Font('Consolas', 8.5)
$form.Controls.Add($logBox)

function Log {
    param([string]$Text)
    $logBox.AppendText($Text + "`r`n")
    $logBox.SelectionStart = $logBox.Text.Length
    $logBox.ScrollToCaret()
}
function Set-Status {
    param([string]$Text, [int]$R = 100, [int]$G = 106, [int]$B = 120)
    $status.Text = $Text
    $status.ForeColor = [System.Drawing.Color]::FromArgb($R, $G, $B)
}

$btnPair = Add-Button -Text '绑定课堂' -X 28 -Y 160 -W 200 -OnClick {
    $btnPair.Enabled = $false
    $logBox.Clear()

    try {
        if (-not $Cli) { throw '找不到 vigil-cli.exe，请重新安装 Vigil 学生端。' }

        $code = $codeInput.Text.Trim()
        if ($code -notmatch '^\d{4}$') { throw '请输入 4 位数字口令。' }

        $manualIp = $ipInput.Text.Trim()
        $candidates = @()

        if ($manualIp -match '^\d{1,3}(\.\d{1,3}){3}$') {
            Set-Status '正在连接教师机…'
            if (Test-TeacherAlive -Ip $manualIp) { $candidates = @($manualIp) }
            else { throw "指定的教师机 $manualIp 没有响应，请核对 IP 与防火墙。" }
        } else {
            Set-Status '正在扫描本网段…'
            Log '扫描局域网中的 Vigil 教师端（约 2 秒）…'
            $targets = Get-ScanTargets
            $open = Test-PortBatch -Addresses $targets -Port $PairPort -TimeoutMs $ConnectMs
            Log "发现 $($open.Count) 个候选设备"
            foreach ($ip in $open) {
                if (Test-TeacherAlive -Ip $ip) { $candidates += $ip; Log "  教师端：$ip" }
            }
            if ($candidates.Count -eq 0) { throw '没有在局域网中找到教师端。请确认教师端已点「开始配对」，或手动填写教师机 IP。' }
        }

        Set-Status '正在校验口令…'
        $pem = $null
        $hit = $null
        foreach ($ip in $candidates) {
            $pem = Invoke-PairRequest -Ip $ip -Code $code
            if ($pem) { $hit = $ip; break }
        }
        if (-not $pem) { throw '口令不正确，或教师端口令已更换。请向老师确认。' }
        Log "口令验证通过：$hit"

        Set-Status '正在写入认证密钥…'
        $null = Import-PublicKey -Pem $pem
        Log '已写入课堂公钥 classroom/public'

        # 学生端必须切到密钥认证，否则教师端公钥不会生效
        $null = & $Cli config set 'Authentication/Method' 'KeyFile' 2>&1
        if ($LASTEXITCODE -ne 0) { Log '警告：认证方式设置失败，请手动检查配置' }
        else { Log '认证方式已设为 KeyFile' }

        Set-Status '正在重启 Vigil 服务…'
        if (Restart-VigilService) { Log 'Vigil 服务已重启' }
        else { Log '警告：服务重启失败，请手动重启 VigilService' }

        Set-Status '绑定成功，已被纳入课堂' 16 124 16
        Log ''
        Log '完成。请回到座位等待老师连接。'
        $btnPair.Text = '重新绑定'
    } catch {
        Set-Status '绑定失败' 176 42 42
        Log ('错误：' + $_.Exception.Message)
    } finally {
        $btnPair.Enabled = $true
    }
}

$form.Add_Shown({ $codeInput.Focus() | Out-Null })
$form.AcceptButton = $btnPair

$logBox.AppendText("把老师屏幕上的 4 位数字输入左侧，然后点「绑定课堂」。`r`n")
$logBox.AppendText("如果自动扫描失败，在右侧填写教师机 IP 再试。`r`n")

[void]$form.ShowDialog()
