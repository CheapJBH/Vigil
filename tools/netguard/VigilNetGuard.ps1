<#
.SYNOPSIS
    Vigil 网络访问白名单：默认阻断全部出站，只放行白名单。

.DESCRIPTION
    Windows 防火墙是 IP/端口/进程 级过滤，不理解域名，也无法识别私有二进制协议
    （Minecraft、游戏客户端、P2P 等）。因此本工具采用唯一可靠的模型：

        出站默认动作 = Block
        白名单      = 域名解析出的 IP + IP/网段 + 端口 + 程序

    未登记的任何流量都会被丢包，与它使用什么协议无关。

.PARAMETER Policy
    策略 JSON 路径。

.PARAMETER Status
    显示当前生效状态。

.PARAMETER Clear
    删除本工具创建的全部规则并恢复出站默认动作。

.PARAMETER DryRun
    只打印将要执行的规则，不修改系统。

.PARAMETER SkipDefaultAction
    只创建白名单规则，不改动"出站默认 Block"。
    用于测试或在已用组策略统一阻断的环境。

.EXAMPLE
    .\VigilNetGuard.ps1 -Policy .\netguard-policy.json
#>
[CmdletBinding(DefaultParameterSetName = 'Apply')]
param(
    [Parameter(ParameterSetName = 'Apply', Position = 0)]
    [string]$Policy = "$PSScriptRoot\netguard-policy.json",

    [Parameter(ParameterSetName = 'Status')]
    [switch]$Status,

    [Parameter(ParameterSetName = 'Clear')]
    [switch]$Clear,

    [Parameter(ParameterSetName = 'Apply')]
    [switch]$DryRun,

    [Parameter(ParameterSetName = 'Apply')]
    [switch]$SkipDefaultAction
)

$ErrorActionPreference = 'Stop'
$script:ParamSet = $PSCmdlet.ParameterSetName

$GroupName   = 'Vigil NetGuard'
$StateDir    = Join-Path $env:ProgramData 'Vigil\netguard'
$StateFile   = Join-Path $StateDir 'state.json'
$Profiles    = @('Domain', 'Private', 'Public')

# ---------------------------------------------------------------- 通用工具

function Assert-Administrator {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $pr = New-Object Security.Principal.WindowsPrincipal($id)
    if (-not $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host '需要管理员权限，正在尝试自动提升...' -ForegroundColor Yellow
        $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
        if ($script:ParamSet -eq 'Apply') { $argList += @('-Policy', "`"$Policy`"") }
        if ($Status) { $argList += '-Status' }
        if ($Clear)  { $argList += '-Clear' }
        if ($DryRun) { $argList += '-DryRun' }
        if ($SkipDefaultAction) { $argList += '-SkipDefaultAction' }
        Start-Process -FilePath (Get-Process -Id $PID).Path -Verb RunAs -ArgumentList $argList
        exit
    }
}

function Get-DefaultPolicy {
    @{
        enabled                = $true
        defaultOutboundAction  = 'Block'
        allowLoopback          = $true
        allowLocalSubnet       = $true
        lanCidrs               = @()
        domains                = @()
        ips                    = @()
        ports                  = @()
        programs               = @()
        allowDnsServers        = $true
        refreshSeconds         = 60
    }
}

function Read-PolicyFile([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "策略文件不存在: $Path"
    }
    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    $p = Get-DefaultPolicy
    foreach ($k in @($raw.PSObject.Properties.Name)) {
        $p[$k] = $raw.$k
    }
    return $p
}

function Resolve-AddressList {
    param([string[]]$Names)
    $result = New-Object System.Collections.Generic.List[string]
    foreach ($n in $Names) {
        if ([string]::IsNullOrWhiteSpace($n)) { continue }
        $n = $n.Trim()
        # 已经是 IP 或 CIDR
        if ($n -match '^[0-9a-fA-F\.\:]+(/\d{1,3})?$') {
            $result.Add($n); continue
        }
        try {
            $ips = [System.Net.Dns]::GetHostAddresses($n) |
                   Where-Object { $_.AddressFamily -eq 'InterNetwork' } |
                   ForEach-Object { $_.IPAddressToString }
            if ($ips) {
                foreach ($ip in $ips) { $result.Add($ip) }
                Write-Verbose "解析 $n -> $($ips -join ', ')"
            } else {
                Write-Warning "域名无 IPv4 记录: $n"
            }
        } catch {
            Write-Warning "域名解析失败: $n ($($_.Exception.Message))"
        }
    }
    return ($result | Select-Object -Unique)
}

function Remove-NetGuardRules {
    $existing = Get-NetFirewallRule -Group $GroupName -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "移除旧规则 $($existing.Count) 条..."
        $existing | Remove-NetFirewallRule -ErrorAction SilentlyContinue
    }
}

function New-NetGuardRule {
    param(
        [string]$Name,
        [hashtable]$RuleArgs,
        [switch]$DryRun
    )
    if ($DryRun) {
        $desc = ($RuleArgs.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ' '
        Write-Host "[dry-run] $Name :: $desc" -ForegroundColor DarkGray
        return
    }
    $base = @{
        DisplayName = "NetGuard - $Name"
        Group       = $GroupName
        Direction   = 'Outbound'
        Action      = 'Allow'
        Profile     = 'Any'
        Enabled     = 'True'
    }
    foreach ($k in $RuleArgs.Keys) {
        if ($null -ne $RuleArgs[$k] -and "$($RuleArgs[$k])" -ne '') { $base[$k] = $RuleArgs[$k] }
    }
    New-NetFirewallRule @base | Out-Null
}

# ---------------------------------------------------------------- 应用策略

function Apply-Policy {
    param($p, [switch]$DryRun, [switch]$SkipDefaultAction)

    if (-not $p.enabled) {
        Write-Host '策略 enabled=false，执行清理。'
        Clear-Policy
        return
    }

    Assert-Administrator
    if (-not (Test-Path $StateDir)) { New-Item -ItemType Directory -Force $StateDir | Out-Null }

    # 记录原始出站默认动作，便于 -Clear 精确还原
    if (-not (Test-Path $StateFile)) {
        $orig = @{}
        foreach ($pr in $Profiles) {
            $orig[$pr] = (Get-NetFirewallProfile -Profile $pr).DefaultOutboundAction.ToString()
        }
        [IO.File]::WriteAllText($StateFile, (@{ defaultOutbound = $orig } | ConvertTo-Json), (New-Object Text.UTF8Encoding($false)))
        Write-Verbose "已保存原始设置: $($orig | ConvertTo-Json -Compress)"
    }

    Remove-NetGuardRules

    $created = 0

    # 1) 回环
    if ($p.allowLoopback) {
        New-NetGuardRule -Name 'loopback' -DryRun:$DryRun -RuleArgs @{
            RemoteAddress = '127.0.0.0/8'
        }
        $created++
    }

    # 2) 局域网 / 指定网段（Vigil 自身通信必须保留）
    if ($p.allowLocalSubnet) {
        New-NetGuardRule -Name 'local-subnet' -DryRun:$DryRun -RuleArgs @{ RemoteAddress = 'LocalSubnet' }
        $created++
    }
    $lanList = @($p.lanCidrs | Where-Object { $_ })
    if ($lanList.Count -gt 0) {
        New-NetGuardRule -Name 'lan-cidrs' -DryRun:$DryRun -RuleArgs @{ RemoteAddress = $lanList }
        $created++
    }

    # 3) DNS 服务器（否则白名单域名无法解析）
    if ($p.allowDnsServers) {
        $dns = @()
        try {
            $dns = Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction Stop |
                   ForEach-Object { $_.ServerAddresses } |
                   Where-Object { $_ -and $_ -ne '127.0.0.1' } |
                   Select-Object -Unique
        } catch { Write-Warning "读取 DNS 服务器失败: $($_.Exception.Message)" }
        if ($dns -and $dns.Count -gt 0) {
            New-NetGuardRule -Name 'dns-servers' -DryRun:$DryRun -RuleArgs @{
                RemoteAddress = @($dns)
                Protocol      = 'UDP'
                RemotePort    = 53
            }
            New-NetGuardRule -Name 'dns-servers-tcp' -DryRun:$DryRun -RuleArgs @{
                RemoteAddress = @($dns)
                Protocol      = 'TCP'
                RemotePort    = 53
            }
            $created += 2
        }
    }

    # 4) 域名解析后的 IP
    $domainIps = @(Resolve-AddressList -Names @($p.domains))
    if ($domainIps.Count -gt 0) {
        New-NetGuardRule -Name "domains-$($domainIps.Count)ips" -DryRun:$DryRun -RuleArgs @{
            RemoteAddress = $domainIps
        }
        $created++
        Write-Host "域名白名单: $($p.domains -join ', ') -> $($domainIps.Count) 个 IP"
    }

    # 5) 显式 IP / 网段
    $ipList = @($p.ips | Where-Object { $_ })
    if ($ipList.Count -gt 0) {
        New-NetGuardRule -Name 'ip-list' -DryRun:$DryRun -RuleArgs @{ RemoteAddress = $ipList }
        $created++
    }

    # 6) 端口规则（MC 等）
    foreach ($entry in @($p.ports)) {
        if (-not $entry -or -not $entry.ip -or -not $entry.port) { continue }
        $targets = @(Resolve-AddressList -Names @($entry.ip))
        if ($targets.Count -eq 0) { continue }
        $proto = 'TCP'
        if ($entry.PSObject.Properties['protocol'] -and $entry.protocol) { $proto = "$($entry.protocol)".ToUpper() }
        New-NetGuardRule -Name "port-$($entry.port)-$($entry.ip)" -DryRun:$DryRun -RuleArgs @{
            RemoteAddress = $targets
            Protocol      = $proto
            RemotePort    = [int]$entry.port
        }
        $created++
    }

    # 7) 程序白名单
    foreach ($prog in @($p.programs)) {
        if ([string]::IsNullOrWhiteSpace($prog)) { continue }
        if (-not (Test-Path -LiteralPath $prog)) {
            Write-Warning "程序不存在，跳过: $prog"
            continue
        }
        New-NetGuardRule -Name "prog-$([IO.Path]::GetFileName($prog))" -DryRun:$DryRun -RuleArgs @{
            Program = $prog
        }
        $created++
    }

    # 8) 出站默认阻断（最后一步，避免中途断掉自身连接）
    if (-not $SkipDefaultAction) {
        $action = if ($p.defaultOutboundAction) { $p.defaultOutboundAction } else { 'Block' }
        if ($DryRun) {
            Write-Host "[dry-run] Set-NetFirewallProfile -DefaultOutboundAction $action" -ForegroundColor DarkGray
        } else {
            foreach ($pr in $Profiles) {
                Set-NetFirewallProfile -Profile $pr -DefaultOutboundAction $action
            }
            Write-Host "出站默认动作已设为 $action" -ForegroundColor Yellow
        }
    }

    Write-Host "NetGuard 已应用：$created 组白名单规则，默认阻断未登记流量。" -ForegroundColor Green
}

# ---------------------------------------------------------------- 清理

function Clear-Policy {
    Assert-Administrator
    Remove-NetGuardRules
    if (Test-Path -LiteralPath $StateFile) {
        try {
            $state = Get-Content -LiteralPath $StateFile -Raw | ConvertFrom-Json
            foreach ($pr in $Profiles) {
                $val = $state.defaultOutbound.$pr
                if ($val) {
                    Set-NetFirewallProfile -Profile $pr -DefaultOutboundAction $val
                    Write-Host "恢复 $pr 出站默认动作: $val"
                }
            }
        } catch {
            Write-Warning "恢复默认动作失败: $($_.Exception.Message)"
        }
        Remove-Item -LiteralPath $StateFile -Force -ErrorAction SilentlyContinue
    } else {
        foreach ($pr in $Profiles) {
            Set-NetFirewallProfile -Profile $pr -DefaultOutboundAction Allow
        }
        Write-Host '未找到备份，出站默认动作恢复为 Allow。'
    }
    Write-Host 'NetGuard 已清除。' -ForegroundColor Green
}

# ---------------------------------------------------------------- 状态

function Show-Status {
    $rules = @(Get-NetFirewallRule -Group $GroupName -ErrorAction SilentlyContinue)
    Write-Host "== Vigil NetGuard 状态 ==" -ForegroundColor Cyan
    Write-Host "规则数量: $($rules.Count)"
    foreach ($pr in $Profiles) {
        $fp = Get-NetFirewallProfile -Profile $pr
        Write-Host ("  {0,-8} 出站默认: {1}" -f $pr, $fp.DefaultOutboundAction)
    }
    if ($rules.Count -gt 0) {
        $rules | Select-Object DisplayName, Enabled, Action | Format-Table -AutoSize
    }
    $task = Get-ScheduledTask -TaskName 'VigilNetGuard' -ErrorAction SilentlyContinue
    if ($task) {
        Write-Host "守护任务: $($task.State)"
    } else {
        Write-Host '守护任务: 未安装'
    }
}

# ---------------------------------------------------------------- 入口

switch ($script:ParamSet) {
    'Status' { Show-Status }
    'Clear'  { Clear-Policy }
    default {
        $p = Read-PolicyFile -Path $Policy
        Apply-Policy -p $p -DryRun:$DryRun -SkipDefaultAction:$SkipDefaultAction
    }
}
