Set-StrictMode -Version 2.0

function Get-NestedValue {
    param([object]$Object, [string[]]$Path)
    $value = $Object
    foreach ($part in $Path) {
        if ($null -eq $value) { return $null }
        $value = Get-PropertyValue $value $part
    }
    return $value
}

function ConvertTo-CsvSummary {
    param([object]$Report)
    $inventory = Get-NestedValue $Report @("diagnostics", "inventory", "data")
    $batteryList = @(Get-NestedValue $Report @("diagnostics", "battery", "data", "batteries"))
    $battery = if ($batteryList.Count -gt 0) { $batteryList[0] } else { $null }
    $diskList = @(Get-NestedValue $Report @("diagnostics", "storage", "data", "disks"))
    $disk = if ($diskList.Count -gt 0) { $diskList[0] } else { $null }

    [pscustomobject]@{
        RunId = $Report.run.runId
        StartedAtUtc = $Report.run.startedAtUtc
        ComputerName = $Report.run.computerName
        SerialNumber = Get-PropertyValue $inventory "serialNumber"
        Manufacturer = Get-PropertyValue $inventory "manufacturer"
        Model = Get-PropertyValue $inventory "model"
        WindowsBuild = Get-PropertyValue $inventory "windowsBuildNumber"
        RAM_GB = Get-NestedValue $inventory @("memory", "totalGB")
        BatteryHealthPct = Get-PropertyValue $battery "healthPct"
        BatteryCycleCount = Get-PropertyValue $battery "cycleCount"
        StorageModel = Get-PropertyValue $disk "friendlyName"
        StorageHealth = Get-PropertyValue $disk "healthStatus"
        StorageReadMBps = Get-NestedValue $Report @("diagnostics", "storage", "data", "performance", "readMBps")
        StorageWriteMBps = Get-NestedValue $Report @("diagnostics", "storage", "data", "performance", "writeMBps")
        CPUThroughputMBps = Get-NestedValue $Report @("diagnostics", "cpuPerformance", "data", "throughputMBps")
        MemoryThroughputMBps = Get-NestedValue $Report @("diagnostics", "memoryPerformance", "data", "throughputMBps")
        ProblemDeviceCount = Get-NestedValue $Report @("diagnostics", "devices", "data", "problemDeviceCount")
        Grade = $Report.result.grade
        Score = $Report.result.score
        Warnings = ($Report.result.warnings -join " | ")
    }
}

function ConvertTo-HtmlReport {
    param([object]$Report)
    $summary = ConvertTo-CsvSummary $Report
    $rows = foreach ($property in $summary.PSObject.Properties) {
        $value = if ($null -eq $property.Value) { "UNAVAILABLE" } else { [string]$property.Value }
        "<tr><th>$([Net.WebUtility]::HtmlEncode($property.Name))</th><td>$([Net.WebUtility]::HtmlEncode($value))</td></tr>"
    }
    $raw = $Report | ConvertTo-Json -Depth 12
    @"
<!doctype html><html><head><meta charset="utf-8"><title>HW Laptop Grader</title>
<style>body{font:16px Segoe UI,Arial,sans-serif;max-width:1000px;margin:2rem auto;padding:0 1rem;color:#222}table{border-collapse:collapse;width:100%}th,td{border:1px solid #ccc;padding:.45rem;text-align:left}th{width:34%;background:#f4f4f4}pre{white-space:pre-wrap;background:#f7f7f7;padding:1rem;overflow:auto}.muted{color:#666}</style></head>
<body><h1>HW Laptop Grader</h1><p class="muted">Run $([Net.WebUtility]::HtmlEncode($Report.run.runId))</p><table>$($rows -join "`n")</table>
<h2>Raw result</h2><pre>$([Net.WebUtility]::HtmlEncode($raw))</pre></body></html>
"@
}

function Write-GraderOutputs {
    param([object]$Report, [string]$OutputDirectory)
    if (-not (Test-Path -LiteralPath $OutputDirectory)) { New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null }
    $prefix = "grader-{0}-{1}" -f $Report.run.computerName, (Get-Date -Format "yyyyMMdd-HHmmss")
    $jsonPath = Join-Path $OutputDirectory "$prefix.json"
    $csvPath = Join-Path $OutputDirectory "$prefix.csv"
    $htmlPath = Join-Path $OutputDirectory "$prefix.html"
    $Report | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
    ConvertTo-CsvSummary $Report | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8
    ConvertTo-HtmlReport $Report | Set-Content -LiteralPath $htmlPath -Encoding UTF8
    [pscustomobject]@{ json = $jsonPath; csv = $csvPath; html = $htmlPath }
}

Export-ModuleMember -Function Write-GraderOutputs, ConvertTo-CsvSummary, ConvertTo-HtmlReport

