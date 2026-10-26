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

# Run the actual entrypoint through architecture preflight only. The next
# statement changes execution policy; no provisioning code is executed here.
$preflightEnd = $script.IndexOf('Set-ExecutionPolicy RemoteSigned')
if ($preflightEnd -lt 0) { throw 'Missing execution-policy boundary.' }
$preflight = [scriptblock]::Create($script.Substring(0, $preflightEnd) + "`n`$Architecture")

if ($env:OS -eq 'Windows_NT') {
    $nativeArchitecture = & $preflight -DryRun -WarningAction SilentlyContinue
    if ($nativeArchitecture -notin @('x86_64', 'arm64')) {
        throw "Unexpected native Windows architecture: $nativeArchitecture"
    }
}

# Mock native CPU discovery independently of the host process architecture.
function Get-CimInstance {
    param([string]$ClassName, [string]$ErrorAction)
    if ($ClassName -ne 'Win32_Processor') { throw "Unexpected CIM query: $ClassName" }
    if ($script:FailCpuQuery) { throw 'CPU query failed' }
    foreach ($code in $script:CpuCodes) { [pscustomobject]@{ Architecture = $code } }
}

function Assert-ArchitectureCase {
    param([object[]]$Codes, [bool]$Preview, [string]$ExpectedArchitecture, [string]$ExpectedError)
    $script:CpuCodes = $Codes
    $caught = $null
    $result = $null
    try {
        $result = & $preflight -DryRun:$Preview -WarningAction SilentlyContinue
    } catch {
        $caught = $_.Exception.Message
    }
    if ($ExpectedError) {
        if (-not $caught -or -not $caught.Contains($ExpectedError)) {
            throw "Expected '$ExpectedError', got '$caught'"
        }
    } elseif ($caught) {
        throw "Unexpected architecture rejection: $caught"
    }
    if ($ExpectedArchitecture -and $result -ne $ExpectedArchitecture) {
        throw "Expected architecture '$ExpectedArchitecture', got '$result'"
    }
}

$script:FailCpuQuery = $false
# An ARM64 CPU must remain experimental even in an emulated AMD64 process.
Assert-ArchitectureCase @(9) $true 'x86_64' ''
Assert-ArchitectureCase @(9, 9) $false 'x86_64' ''
Assert-ArchitectureCase @(12) $true 'arm64' ''
Assert-ArchitectureCase @(12) $false '' 'Use -DryRun'
foreach ($code in @(0, 5, 6, 99)) {
    Assert-ArchitectureCase @($code) $true '' 'Unsupported Windows processor architecture'
    Assert-ArchitectureCase @($code) $false '' 'Unsupported Windows processor architecture'
}
Assert-ArchitectureCase @() $false '' 'Unable to determine a single native CPU architecture'
Assert-ArchitectureCase @(9, 12) $false '' 'Unable to determine a single native CPU architecture'
$script:FailCpuQuery = $true
Assert-ArchitectureCase @() $true '' 'CPU query failed'
Write-Host 'Windows architecture behavior checks passed.'
