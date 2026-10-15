Set-StrictMode -Version 2.0

function Measure-StoragePerformance {
    param([object]$Config, [string]$WorkingDirectory)

    if (-not $Config.enabled) { return [ordered]@{ status = "NOT_RUN"; reason = "DISABLED" } }
    $fileSizeMB = [math]::Min([math]::Max([int]$Config.fileSizeMB, 8), 256)
    $blockSizeKB = [math]::Min([math]::Max([int]$Config.blockSizeKB, 64), 4096)
    $testPath = Join-Path $WorkingDirectory ("storage-test-{0}.tmp" -f [guid]::NewGuid().ToString("N"))
    $buffer = New-Object byte[] ($blockSizeKB * 1KB)
    (New-Object Random 8675309).NextBytes($buffer)
    $targetBytes = [long]$fileSizeMB * 1MB

    try {
        $written = 0L
        $writeWatch = [Diagnostics.Stopwatch]::StartNew()
        $stream = New-Object IO.FileStream($testPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None, $buffer.Length, [IO.FileOptions]::SequentialScan)
        try {
            while ($written -lt $targetBytes) {
                $count = [int][math]::Min($buffer.Length, $targetBytes - $written)
                $stream.Write($buffer, 0, $count)
                $written += $count
            }
            $stream.Flush($true)
        }
        finally { $stream.Dispose() }
        $writeWatch.Stop()

        $read = 0L
        $readWatch = [Diagnostics.Stopwatch]::StartNew()
        $stream = New-Object IO.FileStream($testPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read, $buffer.Length, [IO.FileOptions]::SequentialScan)
        try {
            do {
                $count = $stream.Read($buffer, 0, $buffer.Length)
                $read += $count
            } while ($count -gt 0)
        }
        finally { $stream.Dispose() }
        $readWatch.Stop()

        [ordered]@{
            status = "OK"
            fileSizeMB = $fileSizeMB
            blockSizeKB = $blockSizeKB
            writeMBps = if ($writeWatch.Elapsed.TotalSeconds -gt 0) { [math]::Round(($written / 1MB) / $writeWatch.Elapsed.TotalSeconds, 2) } else { $null }
            readMBps = if ($readWatch.Elapsed.TotalSeconds -gt 0) { [math]::Round(($read / 1MB) / $readWatch.Elapsed.TotalSeconds, 2) } else { $null }
            note = "Short capped sequential test; results may include Windows cache effects."
        }
    }
    catch { [ordered]@{ status = "ERROR"; error = $_.Exception.Message } }
    finally { if (Test-Path -LiteralPath $testPath) { Remove-Item -LiteralPath $testPath -Force -ErrorAction SilentlyContinue } }
}

function Get-StorageDiagnostic {
    param([object]$BenchmarkConfig, [string]$WorkingDirectory)
    try {
        $disks = @()
        if (Get-Command Get-PhysicalDisk -ErrorAction SilentlyContinue) {
            foreach ($disk in @(Get-PhysicalDisk -ErrorAction SilentlyContinue)) {
                $reliability = $null
                if (Get-Command Get-StorageReliabilityCounter -ErrorAction SilentlyContinue) {
                    try { $reliability = $disk | Get-StorageReliabilityCounter -ErrorAction Stop } catch { $reliability = $null }
                }
                $disks += [ordered]@{
                    friendlyName = Get-PropertyValue $disk "FriendlyName"
                    serialNumber = Get-PropertyValue $disk "SerialNumber"
                    mediaType = Get-PropertyValue $disk "MediaType"
                    busType = Get-PropertyValue $disk "BusType"
                    sizeBytes = Get-PropertyValue $disk "Size"
                    healthStatus = Get-PropertyValue $disk "HealthStatus"
                    operationalStatus = @(Get-PropertyValue $disk "OperationalStatus")
                    reliability = if ($null -ne $reliability) {
                        [ordered]@{
                            temperatureC = Get-PropertyValue $reliability "Temperature"
                            readErrorsTotal = Get-PropertyValue $reliability "ReadErrorsTotal"
                            writeErrorsTotal = Get-PropertyValue $reliability "WriteErrorsTotal"
                            wearPct = Get-PropertyValue $reliability "Wear"
                            powerOnHours = Get-PropertyValue $reliability "PowerOnHours"
                        }
                    } else { $null }
                }
            }
        }

        $status = if ($disks.Count -gt 0) { "OK" } else { "UNAVAILABLE" }
        New-DiagnosticResult -Status $status -Data ([ordered]@{
            disks = $disks
            performance = Measure-StoragePerformance -Config $BenchmarkConfig -WorkingDirectory $WorkingDirectory
        })
    }
    catch { New-DiagnosticResult -Status "ERROR" -ErrorMessage $_.Exception.Message }
}

Export-ModuleMember -Function Get-StorageDiagnostic

