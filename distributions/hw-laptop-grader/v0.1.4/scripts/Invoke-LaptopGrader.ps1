[CmdletBinding()]
param(
    [string]$ConfigPath = (Join-Path (Split-Path -Parent $PSScriptRoot) "config\grader.config.json"),
    [string]$OutputDirectory = "C:\ProgramData\HW-Laptop-Grader\Results",
    [string]$CollectorUrl,
    [switch]$SkipSubmission
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

if (-not (Test-Path -LiteralPath $ConfigPath)) { throw "Configuration not found: $ConfigPath" }
$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
if (-not [string]::IsNullOrWhiteSpace($CollectorUrl)) {
    $config.submission.endpoint = $CollectorUrl
    $config.submission.enabled = $true
}
if ($SkipSubmission) { $config.submission.enabled = $false }

$modulePath = Join-Path $PSScriptRoot "modules"
Import-Module (Join-Path $modulePath "Common.psm1") -Force -Global
foreach ($module in @("HardwareInventory", "Battery", "Storage", "CpuPerformance", "Memory", "Reliability", "Devices", "NetworkSecurity", "WindowsHealth", "Scoring", "Output", "Submission")) {
    Import-Module (Join-Path $modulePath "$module.psm1") -Force
}

if (-not (Test-Path -LiteralPath $OutputDirectory)) { New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null }
$started = (Get-Date).ToUniversalTime()
$runId = [guid]::NewGuid().ToString()
Write-Host "HW Laptop Grader $($config.graderVersion)"
Write-Host "Run ID: $runId"

$diagnostics = [ordered]@{}
Write-Host "Collecting hardware inventory..."
$diagnostics.inventory = Get-HardwareInventoryDiagnostic
Write-Host "Collecting battery data..."
$diagnostics.battery = Get-BatteryDiagnostic
Write-Host "Collecting storage health and short performance sample..."
$diagnostics.storage = Get-StorageDiagnostic -BenchmarkConfig $config.benchmarks.storage -WorkingDirectory $OutputDirectory
Write-Host "Measuring CPU performance..."
$diagnostics.cpuPerformance = Get-CpuPerformanceDiagnostic -BenchmarkConfig $config.benchmarks.cpu
Write-Host "Measuring memory performance..."
$diagnostics.memoryPerformance = Get-MemoryDiagnostic -BenchmarkConfig $config.benchmarks.memory
Write-Host "Reviewing recent reliability events..."
$diagnostics.reliability = Get-ReliabilityDiagnostic -LookbackDays ([int]$config.eventLogLookbackDays)
Write-Host "Checking Windows devices..."
$diagnostics.devices = Get-DevicesDiagnostic
Write-Host "Collecting network and security data..."
$diagnostics.networkSecurity = Get-NetworkSecurityDiagnostic
Write-Host "Collecting Windows health and ePSA-equivalent signals..."
$diagnostics.windowsHealth = Get-WindowsHealthDiagnostic

$diagnosticObject = [pscustomobject]$diagnostics
$result = Get-ConservativeScore -Diagnostics $diagnosticObject -ScoringConfig $config.scoring
$completed = (Get-Date).ToUniversalTime()
$report = [pscustomobject]@{
    schemaVersion = [string]$config.schemaVersion
    run = [pscustomobject]@{
        runId = $runId
        startedAtUtc = $started.ToString("o")
        completedAtUtc = $completed.ToString("o")
        durationSeconds = [math]::Round(($completed - $started).TotalSeconds, 2)
        graderVersion = [string]$config.graderVersion
        computerName = [string]$env:COMPUTERNAME
    }
    diagnostics = $diagnosticObject
    result = $result
}

$paths = Write-GraderOutputs -Report $report -OutputDirectory $OutputDirectory
$submission = Submit-GraderResult -Report $report -SubmissionConfig $config.submission

Write-Host "JSON: $($paths.json)"
Write-Host "CSV:  $($paths.csv)"
Write-Host "HTML: $($paths.html)"
Write-Host "Submission: $($submission.status)"
if ($submission.status -eq "ERROR") { Write-Warning "Submission failed: $($submission.reason). Local results were preserved." }

[pscustomobject]@{ report = $report; paths = $paths; submission = $submission }

