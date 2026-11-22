<#
.SYNOPSIS
    Vigil NetGuard 守护进程：定时刷新域名 IP，并补回被删除的规则。

.DESCRIPTION
    由计划任务 VigilNetGuard 以 SYSTEM 身份每 60 秒运行一次。
    域名解析出的 IP 会变化（CDN），必须周期性重建规则；
    同时防止普通用户误删或禁用防火墙规则。

.PARAMETER Policy
    策略文件路径。默认 C:\ProgramData\Vigil\netguard\netguard-policy.json

.PARAMETER Install
    安装守护计划任务（需要管理员）。

.PARAMETER Uninstall
    卸载守护计划任务。
#>
[CmdletBinding()]
param(
    [string]$Policy = "$env:ProgramData\Vigil\netguard\netguard-policy.json",
    [switch]$Install,
    [switch]$Uninstall,
    [switch]$Once
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $PSCommandPath
$Core      = Join-Path $ScriptDir 'VigilNetGuard.ps1'
$TaskName  = 'VigilNetGuard'
$GroupName = 'Vigil NetGuard'

if ($Install) {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
            [Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw '安装守护任务需要管理员权限。'
    }
    $action  = New-ScheduledTaskAction -Execute 'powershell.exe' `
        -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $trigger2 = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) `
        -RepetitionInterval (New-TimeSpan -Minutes 1) `
        -RepetitionDuration ([TimeSpan]::FromDays(3650))
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger @($trigger, $trigger2) `
        -Principal $principal -Settings $settings -Force | Out-Null
    Write-Host "已安装计划任务 $TaskName（SYSTEM，开机 + 每分钟）。" -ForegroundColor Green
    return
}

if ($Uninstall) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "已卸载计划任务 $TaskName。" -ForegroundColor Green
    return
}

# ---------------------------------------------------------------- 守护主体

if (-not (Test-Path -LiteralPath $Policy)) {
    Write-Host "策略文件不存在，跳过: $Policy"
    exit 0
}

$p = Get-Content -LiteralPath $Policy -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $p.enabled) { exit 0 }

$rules = @(Get-NetFirewallRule -Group $GroupName -ErrorAction SilentlyContinue)

# 规则被清空 → 完整重建
if ($rules.Count -eq 0) {
    Write-Host '规则缺失，重建...'
    & $Core -Policy $Policy -SkipDefaultAction
    exit 0
}

# 出站默认动作被改回 Allow → 纠正
foreach ($pr in @('Domain', 'Private', 'Public')) {
    $cur = (Get-NetFirewallProfile -Profile $pr).DefaultOutboundAction
    if ($cur -ne 'Block') {
        Write-Host "检测到 $pr 出站默认动作被改为 $cur，恢复 Block。"
        Set-NetFirewallProfile -Profile $pr -DefaultOutboundAction Block
    }
}

# 域名 IP 刷新：仅当解析结果与现有规则不一致时重建
$domains = @($p.domains | Where-Object { $_ })
if ($domains.Count -gt 0) {
    $now = @()
    foreach ($d in $domains) {
        try {
            $now += [System.Net.Dns]::GetHostAddresses($d) |
                    Where-Object { $_.AddressFamily -eq 'InterNetwork' } |
                    ForEach-Object { $_.IPAddressToString }
        } catch { }
    }
    $now = @($now | Select-Object -Unique | Sort-Object)
    $current = @(Get-NetFirewallRule -Group $GroupName -DisplayName 'NetGuard - domains-*' -ErrorAction SilentlyContinue |
                 Get-NetFirewallAddressFilter -ErrorAction SilentlyContinue |
                 ForEach-Object { $_.RemoteAddress } |
                 Where-Object { $_ } | Select-Object -Unique | Sort-Object)
    if (($now -join ',') -ne ($current -join ',')) {
        Write-Host '域名 IP 集合变化，重建规则...'
        & $Core -Policy $Policy -SkipDefaultAction
    }
}

if ($Once) { Write-Host 'NetGuard 守护检查完成。' }
