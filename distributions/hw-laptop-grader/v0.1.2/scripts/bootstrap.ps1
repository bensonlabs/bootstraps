[CmdletBinding()]
param(
    [string]$DistributionRef = "hw-laptop-grader-v0.1.2",
    [string]$BasePath = "C:\ProgramData\HW-Laptop-Grader",
    [string]$CollectorUrl,
    [switch]$SkipSubmission
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Quote-Argument {
    param([string]$Value)
    if ($Value -match '[\s"]') { return '"' + ($Value -replace '"', '\"') + '"' }
    return $Value
}

if (-not (Test-IsAdministrator)) {
    if (-not $PSCommandPath) { throw "Cannot self-elevate because the bootstrap path is unavailable." }
    $arguments = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $PSCommandPath, "-DistributionRef", $DistributionRef, "-BasePath", $BasePath)
    if (-not [string]::IsNullOrWhiteSpace($CollectorUrl)) { $arguments += @("-CollectorUrl", $CollectorUrl) }
    if ($SkipSubmission) { $arguments += "-SkipSubmission" }
    $line = (($arguments | ForEach-Object { Quote-Argument ([string]$_) }) -join " ")
    $process = Start-Process powershell.exe -ArgumentList $line -Verb RunAs -Wait -PassThru
    exit $process.ExitCode
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$scriptDirectory = Join-Path $BasePath "Scripts"
$moduleDirectory = Join-Path $scriptDirectory "modules"
$configDirectory = Join-Path $BasePath "config"
$logDirectory = Join-Path $BasePath "Logs"
$resultDirectory = Join-Path $BasePath "Results"
foreach ($directory in @($scriptDirectory, $moduleDirectory, $configDirectory, $logDirectory, $resultDirectory)) {
    if (-not (Test-Path -LiteralPath $directory)) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
}

$logPath = Join-Path $logDirectory ("bootstrap-{0}.log" -f (Get-Date -Format "yyyyMMdd-HHmmss"))
$exitCode = 0
Start-Transcript -Path $logPath -Append | Out-Null
try {
    Write-Host "HW Laptop Grader bootstrap"
    Write-Host "Distribution: bensonlabs/bootstraps@$DistributionRef"
    Write-Host "Base path: $BasePath"
    $raw = "https://raw.githubusercontent.com/bensonlabs/bootstraps/$DistributionRef/distributions/hw-laptop-grader/v0.1.2"
    $files = @(
        "config/grader.config.json",
        "config/result.schema.json",
        "scripts/Invoke-LaptopGrader.ps1",
        "scripts/modules/Common.psm1",
        "scripts/modules/HardwareInventory.psm1",
        "scripts/modules/Battery.psm1",
        "scripts/modules/Storage.psm1",
        "scripts/modules/CpuPerformance.psm1",
        "scripts/modules/Memory.psm1",
        "scripts/modules/Reliability.psm1",
        "scripts/modules/Devices.psm1",
        "scripts/modules/NetworkSecurity.psm1",
        "scripts/modules/WindowsHealth.psm1",
        "scripts/modules/Scoring.psm1",
        "scripts/modules/Output.psm1",
        "scripts/modules/Submission.psm1"
    )
    foreach ($file in $files) {
        $target = Join-Path $BasePath ($file -replace '/', '\')
        Write-Host "Downloading $file"
        Invoke-WebRequest -Uri "$raw/$file" -OutFile $target -UseBasicParsing
    }

    $graderArgs = @{
        ConfigPath = (Join-Path $configDirectory "grader.config.json")
        OutputDirectory = $resultDirectory
    }
    if (-not [string]::IsNullOrWhiteSpace($CollectorUrl)) { $graderArgs.CollectorUrl = $CollectorUrl }
    if ($SkipSubmission) { $graderArgs.SkipSubmission = $true }
    & (Join-Path $scriptDirectory "Invoke-LaptopGrader.ps1") @graderArgs | Out-Host
    Write-Host "Grading complete."
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)"
    $exitCode = 1
}
finally { Stop-Transcript | Out-Null }
exit $exitCode

