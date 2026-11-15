<#
    Vigil 课堂配对服务（教师端后台进程）
    ------------------------------------------------------------------
    由 VigilTeacherSetup.ps1 启动，不要单独使用。

    行为：
      监听 http://+:<Port>/
        GET /ping                -> "vigil-teacher:<主机名>"，用于学生端探测
        GET /pair?code=<4位数字>  -> 口令正确时返回 PEM 公钥文本
      仅接受私网来源（10/8、172.16/12、192.168/16），其余一律拒绝。
      同一来源连续输错 5 次，锁定 5 分钟。

    参数：
      -Code     当前有效的 4 位口令
      -Port     监听端口，默认 11101
      -KeyName  密钥名称，默认 classroom
      -LogFile  日志文件路径（GUI 轮询展示）
#>

param(
    [Parameter(Mandatory = $true)][string]$Code,
    [int]$Port = 11101,
    [string]$KeyName = 'classroom',
    [string]$LogFile = (Join-Path $env:TEMP 'vigil-pair.log')
)

$ErrorActionPreference = 'Stop'

$MaxTries = 5
$LockMinutes = 5

function Write-Log {
    param([string]$Text)
    $line = '[{0:yyyy-MM-dd HH:mm:ss}] {1}' -f (Get-Date), $Text
    try { Add-Content -Path $LogFile -Value $line -Encoding UTF8 } catch {}
}

function Test-PrivateAddress {
    param([System.Net.IPAddress]$Addr)
    if ($null -eq $Addr) { return $false }
    if ($Addr.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) { return $false }
    $b = $Addr.GetAddressBytes()
    if ($b[0] -eq 10) { return $true }
    if ($b[0] -eq 172 -and $b[1] -ge 16 -and $b[1] -le 31) { return $true }
    if ($b[0] -eq 192 -and $b[1] -eq 168) { return $true }
    if ($b[0] -eq 127) { return $true }
    if ($b[0] -eq 169 -and $b[1] -eq 254) { return $true }   # link-local
    return $false
}

# ------------------------------------------------------------------ 公钥

$tempPem = Join-Path $env:TEMP ("vigil-pub-{0}.pem" -f $PID)
if (Test-Path $tempPem) { Remove-Item $tempPem -Force }

$cli = Join-Path (Split-Path -Parent $PSScriptRoot) 'vigil-cli.exe'
foreach ($candidate in @(
        (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'vigil-cli.exe'),
        'C:\Program Files\Vigil\vigil-cli.exe')) {
    if (Test-Path $candidate) { $cli = $candidate; break }
}

if (-not (Test-Path $cli)) {
    Write-Log "致命错误：找不到 vigil-cli.exe"
    exit 2
}

try {
    $null = & $cli authkeys export "$KeyName/public" $tempPem -f 2>&1
    if (-not (Test-Path $tempPem)) { throw '导出文件未生成' }
    $publicKey = (Get-Content $tempPem -Raw).Trim()
    if ($publicKey -notmatch 'BEGIN PUBLIC KEY') { throw '导出内容不是有效 PEM 公钥' }
} catch {
    Write-Log "致命错误：导出公钥失败 - $($_.Exception.Message)"
    exit 3
} finally {
    if (Test-Path $tempPem) { Remove-Item $tempPem -Force -ErrorAction SilentlyContinue }
}

# ------------------------------------------------------------------ 监听

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://+:$Port/")

try {
    $listener.Start()
} catch {
    Write-Log "致命错误：无法监听 $Port 端口 - $($_.Exception.Message)"
    Write-Log "常见原因：未以管理员身份运行，或端口已被占用。"
    exit 4
}

Write-Log "配对服务已启动，端口 $Port，密钥 $KeyName，主机 $env:COMPUTERNAME"

$failTable = @{}

function Test-Blocked {
    param([string]$Ip)
    $e = $failTable[$Ip]
    if ($null -eq $e) { return $false }
    if ($e.LockUntil -and (Get-Date) -lt $e.LockUntil) { return $true }
    return $false
}

function Add-Failure {
    param([string]$Ip, [string]$Given)
    if (-not $failTable.ContainsKey($Ip)) {
        $failTable[$Ip] = @{ Count = 0; LockUntil = $null }
    }
    $e = $failTable[$Ip]
    $e.Count++
    Write-Log "口令错误：$Ip 提交 \"$Given\"（第 $($e.Count) 次）"
    if ($e.Count -ge $MaxTries) {
        $e.LockUntil = (Get-Date).AddMinutes($LockMinutes)
        $e.Count = 0
        Write-Log "IP $Ip 连续错误达 $MaxTries 次，锁定 $LockMinutes 分钟"
    }
}

$running = $true
while ($running) {
    $ctx = $null
    try {
        $ctx = $listener.GetContext()
    } catch {
        Write-Log "监听中断：$($_.Exception.Message)"
        break
    }

    $req = $ctx.Request
    $res = $ctx.Response
    $remote = '0.0.0.0'
    try { $remote = $req.RemoteEndPoint.Address.ToString() } catch {}

    $status = 200
    $body = ''

    try {
        if (-not (Test-PrivateAddress -Addr $req.RemoteEndPoint.Address)) {
            $status = 403
            $body = 'forbidden'
            Write-Log "拒绝非内网来源：$remote"
        }
        elseif (Test-Blocked -Ip $remote) {
            $status = 429
            $body = 'locked'
            Write-Log "拒绝已锁定来源：$remote"
        }
        elseif ($req.HttpMethod -eq 'GET' -and $req.Url.AbsolutePath -eq '/ping') {
            $body = "vigil-teacher:$env:COMPUTERNAME"
        }
        elseif ($req.HttpMethod -eq 'GET' -and $req.Url.AbsolutePath -eq '/pair') {
            $given = [string]$req.QueryString['code']
            if ($given -and $given -eq $Code) {
                $status = 200
                $body = $publicKey
                $failTable.Remove($remote)
                Write-Log "配对成功：$remote"

                # 把学生机登记到教师端的计算机列表，省去手工添加
                $studentName = [string]$req.QueryString['name']
                try { $studentName = [System.Uri]::UnescapeDataString($studentName) } catch {}
                $studentName = $studentName.Trim()
                if (-not $studentName) { $studentName = $remote }

                try {
                    $dump = & $cli networkobjects dump 2>&1 | Out-String
                    if ($dump -notmatch [regex]::Escape($remote)) {
                        $null = & $cli networkobjects add computer $studentName $remote 2>&1
                        Write-Log "已加入计算机列表：$studentName ($remote)"
                    } else {
                        Write-Log "已在计算机列表中：$remote"
                    }
                } catch {
                    Write-Log "登记学生机失败（不影响配对）：$($_.Exception.Message)"
                }
            } else {
                $status = 403
                $body = 'bad-code'
                Add-Failure -Ip $remote -Given $given
            }
        }
        elseif ($req.HttpMethod -eq 'POST' -and $req.Url.AbsolutePath -eq '/shutdown') {
            $body = 'bye'
            $running = $false
        }
        else {
            $status = 404
            $body = 'not-found'
        }
    } catch {
        $status = 500
        $body = 'error'
        Write-Log "处理请求异常：$($_.Exception.Message)"
    }

    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
        $res.StatusCode = $status
        $res.ContentType = 'text/plain; charset=utf-8'
        $res.ContentLength64 = $bytes.Length
        $res.OutputStream.Write($bytes, 0, $bytes.Length)
        $res.OutputStream.Flush()
    } catch {
    } finally {
        try { $res.Close() } catch {}
    }
}

try { $listener.Stop() } catch {}
Write-Log '配对服务已停止'
