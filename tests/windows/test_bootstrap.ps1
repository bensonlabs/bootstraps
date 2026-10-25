$ErrorActionPreference = 'Stop'
$script = Get-Content 'scripts/bootstrap_windows.ps1' -Raw

foreach ($required in @(
    'Select-Components',
    '[switch]$All',
    '[switch]$IncludeWsl',
    '[switch]$DryRun',
    '$InstallWsl = $IncludeWsl -and -not $SkipWsl',
    'if ($SkipWsl -or -not $InstallWsl)'
)) {
    if (-not $script.Contains($required)) {
        throw "Expected Windows bootstrap content was not found: $required"
    }
}

foreach ($removed in @('Antigravity', 'GitHub Copilot', 'Zed')) {
    if ($script -match [regex]::Escape($removed)) {
        throw "Unexpected Windows bootstrap content was found: $removed"
    }
}

Write-Host 'Windows bootstrap contract checks passed.'
