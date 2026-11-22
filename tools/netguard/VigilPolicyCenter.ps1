<#
.SYNOPSIS
    教师端课堂策略中心：统一设置全班的白名单、模式与保护口令。

.DESCRIPTION
    两种运行方式，互不干扰：

      -Serve   只读 HTTP 服务，学生端 Agent 每 2 分钟拉取 teacher-policy.json。
               每次请求都重新读文件，所以在 GUI 里保存后立即生效，无需重启。

      -Gui     策略编辑器（WinForms），写 teacher-policy.json 并自动递增版本号。
               修改口令时在这里完成 PBKDF2 哈希，明文不出教师机。

      -Install 注册开机自启（SYSTEM），并开放端口。

    策略里的 mode 控制课堂状态：
      lesson  = 上课，严格白名单
      break   = 下课，全部放行（自动在放行时清理防火墙规则）

.PARAMETER Port
    策略服务端口，默认 11109。

.PARAMETER Gui
    打开策略编辑器。

.PARAMETER Install
    安装开机自启与端口授权。

.PARAMETER Status
    显示最近回报的学生机。

.EXAMPLE
    .\VigilPolicyCenter.ps1 -Install
    .\VigilPolicyCenter.ps1 -Gui
#>
[CmdletBinding(DefaultParameterSetName = 'Serve')]
param(
    [Parameter(ParameterSetName = 'Serve')]
    [switch]$Serve,

    [Parameter(ParameterSetName = 'Gui')]
    [switch]$Gui,

    [Parameter(ParameterSetName = 'Install')]
    [switch]$Install,

    [Parameter(ParameterSetName = 'Status')]
    [switch]$Status,

    [int]$Port = 11109
)

$ErrorActionPreference = 'Stop'
$DataDir    = Join-Path $env:ProgramData 'Vigil\policy'
$PolicyFile = Join-Path $DataDir 'teacher-policy.json'
$ReportFile = Join-Path $DataDir 'reports.json'
$TaskName   = 'VigilPolicyCenter'

function Initialize-Store {
    if (-not (Test-Path $DataDir)) { New-Item -ItemType Directory -Force $DataDir | Out-Null }
    if (-not (Test-Path $PolicyFile)) {
        @{
            version = 1
            mode    = 'lesson'
            enabled = $true
            defaultOutboundAction = 'Block'
            allowLoopback = $true
            allowLocalSubnet = $true
            lanCidrs = @('172.17.202.0/24')
            domains = @()
            ips = @()
            ports = @()
            programs = @()
            allowDnsServers = $true
            refreshSeconds = 60
        } | ConvertTo-Json -Depth 6 | ForEach-Object {
            [IO.File]::WriteAllText($PolicyFile, $_, (New-Object Text.UTF8Encoding($false)))
        }
    }
}

function New-PasswordRecord([string]$Plain) {
    $salt = New-Object byte[] 16
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    $rng.GetBytes($salt); $rng.Dispose()
    $kdf = New-Object Security.Cryptography.Rfc2898DeriveBytes(
        $Plain, $salt, 120000, [Security.Cryptography.HashAlgorithmName]::SHA256)
    $hash = $kdf.GetBytes(32); $kdf.Dispose()
    @{
        salt = [Convert]::ToBase64String($salt)
        hash = [Convert]::ToBase64String($hash)
        iterations = 120000
    }
}

# ---------------------------------------------------------------- 编辑器

function Show-Editor {
    Initialize-Store
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $policy = Get-Content $PolicyFile -Raw -Encoding UTF8 | ConvertFrom-Json

    $form = New-Object Windows.Forms.Form
    $form.Text = 'Vigil 课堂策略中心'
    $form.Size = New-Object Drawing.Size(720, 760)
    $form.StartPosition = 'CenterScreen'
    $form.Font = New-Object Drawing.Font('Microsoft YaHei UI', 9)

    function Add-Label($text, $top) {
        $l = New-Object Windows.Forms.Label
        $l.Text = $text
        $l.Location = New-Object Drawing.Point(16, $top)
        $l.Size = New-Object Drawing.Size(660, 20)
        $form.Controls.Add($l)
        return $l
    }

    function Add-Text($text, $top, $height) {
        $t = New-Object Windows.Forms.TextBox
        $t.Multiline = $true
        $t.ScrollBars = 'Vertical'
        $t.Location = New-Object Drawing.Point(16, $top)
        $t.Size = New-Object Drawing.Size(670, $height)
        $t.Text = ($text -join "`r`n")
        $form.Controls.Add($t)
        return $t
    }

    $modeLabel = Add-Label '课堂模式（lesson = 上课严格白名单；break = 下课全部放行）' 12
    $mode = New-Object Windows.Forms.ComboBox
    $mode.DropDownStyle = 'DropDownList'
    $mode.Items.AddRange(@('lesson', 'break'))
    $mode.SelectedItem = if ($policy.mode) { $policy.mode } else { 'lesson' }
    $mode.Location = New-Object Drawing.Point(16, 34)
    $mode.Size = New-Object Drawing.Size(200, 24)
    $form.Controls.Add($mode)

    Add-Label '允许的域名（每行一个）' 68 | Out-Null
    $dom = Add-Text $policy.domains 90 90

    Add-Label '允许的 IP / 网段（每行一个）' 188 | Out-Null
    $ips = Add-Text $policy.ips 210 70

    Add-Label '端口白名单（每行 host:port，如 mc.example.com:25565）' 288 | Out-Null
    $portsText = @($policy.ports | ForEach-Object {
        if ($_.protocol -and $_.protocol -ne 'tcp') { "$($_.ip):$($_.port)/$($_.protocol)" }
        else { "$($_.ip):$($_.port)" }
    })
    $portBox = Add-Text $portsText 310 70

    Add-Label '允许的程序（每行一个完整路径）' 388 | Out-Null
    $prog = Add-Text $policy.programs 410 70

    Add-Label '解除保护口令（留空表示不修改；修改后学生端下次同步生效）' 488 | Out-Null
    $pwd = New-Object Windows.Forms.TextBox
    $pwd.UseSystemPasswordChar = $true
    $pwd.Location = New-Object Drawing.Point(16, 510)
    $pwd.Size = New-Object Drawing.Size(320, 24)
    $form.Controls.Add($pwd)

    $save = New-Object Windows.Forms.Button
    $save.Text = '保存并下发'
    $save.Location = New-Object Drawing.Point(16, 550)
    $save.Size = New-Object Drawing.Size(150, 34)
    $form.Controls.Add($save)

    $hint = New-Object Windows.Forms.Label
    $hint.Location = New-Object Drawing.Point(180, 558)
    $hint.Size = New-Object Drawing.Size(520, 60)
    $hint.Text = "学生端每 2 分钟拉取一次。当前版本：$($policy.version)"
    $form.Controls.Add($hint)

    $save.Add_Click({
        try {
            $cur = Get-Content $PolicyFile -Raw -Encoding UTF8 | ConvertFrom-Json
            $cur.version = [int]$cur.version + 1
            $cur.mode = $mode.SelectedItem
            $cur.enabled = ($mode.SelectedItem -eq 'lesson')
            $cur.domains = @($dom.Text -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
            $cur.ips     = @($ips.Text -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
            $cur.programs = @($prog.Text -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })

            $portList = @()
            foreach ($line in ($portBox.Text -split "`r?`n")) {
                $line = $line.Trim()
                if (-not $line) { continue }
                if ($line -match '^(?<h>[^:]+):(?<p>\d+)(/(?<proto>\w+))?$') {
                    $portList += [pscustomobject]@{
                        ip = $Matches.h; port = [int]$Matches.p
                        protocol = if ($Matches.proto) { $Matches.proto.ToLower() } else { 'tcp' }
                    }
                }
            }
            $cur.ports = $portList

            if ($pwd.Text) {
                $rec = New-PasswordRecord $pwd.Text
                $cur | Add-Member -NotePropertyName guard -NotePropertyValue $rec -Force
            }

            $json = $cur | ConvertTo-Json -Depth 8
            [IO.File]::WriteAllText($PolicyFile, $json, (New-Object Text.UTF8Encoding($false)))
            $hint.Text = "已保存，版本 $($cur.version)。学生端 2 分钟内自动应用。"
            $pwd.Text = ''
        } catch {
            [Windows.Forms.MessageBox]::Show($_.Exception.Message, '保存失败', 'OK', 'Error') | Out-Null
        }
    })

    [void]$form.ShowDialog()
}

# ---------------------------------------------------------------- 服务

function Start-Service_ {
    Initialize-Store
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("http://+:$Port/")
    try { $listener.Start() }
    catch { throw "无法监听 $Port（需要管理员运行并执行 -Install 授权端口）：$($_.Exception.Message)" }

    Write-Host "策略服务已启动: http://+:$Port/  策略文件: $PolicyFile" -ForegroundColor Green
    Write-Host '学生端地址格式: http://<本机IP>:'$Port  -ForegroundColor DarkGray

    while ($listener.IsListening) {
        $ctx = $listener.GetContext()
        $req = $ctx.Request
        $res = $ctx.Response
        try {
            switch ($req.Url.AbsolutePath) {
                '/policy' {
                    $body = Get-Content $PolicyFile -Raw -Encoding UTF8
                    $bytes = [Text.Encoding]::UTF8.GetBytes($body)
                    $res.ContentType = 'application/json; charset=utf-8'
                    $res.OutputStream.Write($bytes, 0, $bytes.Length)
                }
                '/report' {
                    $reader = New-Object IO.StreamReader($req.InputStream, [Text.Encoding]::UTF8)
                    $payload = $reader.ReadToEnd(); $reader.Dispose()
                    $rec = @{ time = (Get-Date).ToString('s'); data = $payload }
                    Add-Content -LiteralPath $ReportFile -Value ($rec | ConvertTo-Json -Compress) -Encoding UTF8
                    $bytes = [Text.Encoding]::UTF8.GetBytes('{"ok":true}')
                    $res.ContentType = 'application/json'
                    $res.OutputStream.Write($bytes, 0, $bytes.Length)
                }
                default {
                    $res.StatusCode = 404
                }
            }
        } catch {
            $res.StatusCode = 500
        } finally {
            $res.Close()
        }
    }
}

# ---------------------------------------------------------------- 入口

switch ($PSCmdlet.ParameterSetName) {

    'Gui' { Show-Editor }

    'Status' {
        Initialize-Store
        $p = Get-Content $PolicyFile -Raw | ConvertFrom-Json
        Write-Host "当前版本: $($p.version)  模式: $($p.mode)" -ForegroundColor Cyan
        Write-Host "域名 $($p.domains.Count) 个 / IP $($p.ips.Count) 个 / 程序 $($p.programs.Count) 个"
        if (Test-Path $ReportFile) {
            Write-Host '--- 最近回报 ---'
            Get-Content $ReportFile -Tail 20 | ForEach-Object {
                try { $o = $_ | ConvertFrom-Json; Write-Host $o.time $o.data } catch { }
            }
        }
    }

    'Install' {
        $id = [Security.Principal.WindowsIdentity]::GetCurrent()
        if (-not (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
                [Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw '安装策略服务需要管理员权限。'
        }
        Initialize-Store
        & netsh http add urlacl "url=http://+:$Port/" user=Everyone | Out-Null
        & netsh advfirewall firewall add rule name="Vigil Policy Center" `
            dir=in action=allow protocol=TCP localport=$Port | Out-Null

        $action = New-ScheduledTaskAction -Execute 'powershell.exe' `
            -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Serve -Port $Port"
        $t1 = New-ScheduledTaskTrigger -AtStartup
        $pr = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
        $st = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries `
            -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew
        Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $t1 `
            -Principal $pr -Settings $st -Force | Out-Null

        Write-Host "策略中心已安装：开机自启，端口 $Port 已放行。" -ForegroundColor Green
        Write-Host "学生端执行：VigilPolicyAgent.ps1 -Install -TeacherUrl http://<本机IP>:$Port" -ForegroundColor Yellow
    }

    default {
        if ($Serve) { Start-Service_ }
        else { Show-Editor }
    }
}
