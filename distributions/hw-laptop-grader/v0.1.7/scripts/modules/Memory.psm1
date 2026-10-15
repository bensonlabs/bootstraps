Set-StrictMode -Version 2.0

function Get-MemoryDiagnostic {
    param([object]$BenchmarkConfig)
    if (-not $BenchmarkConfig.enabled) { return New-DiagnosticResult -Status "NOT_RUN" -Data ([ordered]@{ reason = "DISABLED" }) }
    try {
        $sizeMB = [math]::Min([math]::Max([int]$BenchmarkConfig.bufferSizeMB, 8), 128)
        $passes = [math]::Min([math]::Max([int]$BenchmarkConfig.passes, 1), 64)
        $source = New-Object byte[] ($sizeMB * 1MB)
        $destination = New-Object byte[] ($source.Length)
        (New-Object Random 12345).NextBytes($source)
        $watch = [Diagnostics.Stopwatch]::StartNew()
        for ($i = 0; $i -lt $passes; $i++) { [Buffer]::BlockCopy($source, 0, $destination, 0, $source.Length) }
        $watch.Stop()
        $checksumMatch = ($source[0] -eq $destination[0] -and $source[$source.Length - 1] -eq $destination[$destination.Length - 1])
        New-DiagnosticResult -Status "OK" -Data ([ordered]@{
            method = "Buffer.BlockCopy"
            bufferSizeMB = $sizeMB
            passes = $passes
            durationSeconds = [math]::Round($watch.Elapsed.TotalSeconds, 3)
            throughputMBps = if ($watch.Elapsed.TotalSeconds -gt 0) { [math]::Round(($sizeMB * $passes) / $watch.Elapsed.TotalSeconds, 2) } else { $null }
            boundaryChecksumMatch = $checksumMatch
        })
    }
    catch { New-DiagnosticResult -Status "ERROR" -ErrorMessage $_.Exception.Message }
}

Export-ModuleMember -Function Get-MemoryDiagnostic

