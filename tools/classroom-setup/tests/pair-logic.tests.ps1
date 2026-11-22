# 配对判定逻辑测试（与 VigilPairServer.ps1 中 /pair 分支保持同一表达式）
# 运行：pwsh -NoProfile -File tests/pair-logic.tests.ps1

$ErrorActionPreference = 'Stop'
$script:failed = 0
$script:passed = 0

function Test-Case {
    param(
        [string]$Name,
        [bool]$AutoAccept,
        [string]$Given,
        [string]$Auto,
        [string]$Code,
        [bool]$Expect
    )

    # ---- 与 VigilPairServer.ps1 /pair 分支完全一致的判定 ----
    $allowByCode = ($Given -and $Given -eq $Code)
    $allowByAuto = $AutoAccept -and (($Auto -eq '1') -or (-not $Given))
    $actual = [bool]($allowByCode -or $allowByAuto)
    # ---------------------------------------------------------

    if ($actual -eq $Expect) {
        $script:passed++
        Write-Host ("  PASS  {0}  (allow={1})" -f $Name, $actual) -ForegroundColor Green
    } else {
        $script:failed++
        Write-Host ("  FAIL  {0}  期望 {1} 实际 {2}" -f $Name, $Expect, $actual) -ForegroundColor Red
    }
}

Write-Host '== 免口令模式（AutoAccept = true）=='
Test-Case '学生端带 auto=1'          -AutoAccept $true  -Given ''     -Auto '1'  -Code '1234' -Expect $true
Test-Case '学生端不带任何参数'        -AutoAccept $true  -Given ''     -Auto ''   -Code '1234' -Expect $true
Test-Case '学生端同时带口令'          -AutoAccept $true  -Given '1234' -Auto '1'  -Code '1234' -Expect $true
Test-Case '学生端带错误口令+auto'     -AutoAccept $true  -Given '9999' -Auto '1'  -Code '1234' -Expect $true

Write-Host '== 口令模式（AutoAccept = false）=='
Test-Case '口令正确'                  -AutoAccept $false -Given '1234' -Auto ''   -Code '1234' -Expect $true
Test-Case '口令错误'                  -AutoAccept $false -Given '9999' -Auto ''   -Code '1234' -Expect $false
Test-Case '空口令（不能免口令）'      -AutoAccept $false -Given ''     -Auto ''   -Code '1234' -Expect $false
Test-Case '仅 auto=1 不给口令'        -AutoAccept $false -Given ''     -Auto '1'  -Code '1234' -Expect $false
Test-Case '口令正确但带 auto=1'       -AutoAccept $false -Given '1234' -Auto '1'  -Code '1234' -Expect $true

Write-Host ''
Write-Host ("结果：{0} 通过，{1} 失败" -f $script:passed, $script:failed)
if ($script:failed -gt 0) { exit 1 }
exit 0
