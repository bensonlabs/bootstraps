Set-StrictMode -Version 2.0

function Get-CpuPerformanceDiagnostic {
    param([object]$BenchmarkConfig)
    if (-not $BenchmarkConfig.enabled) { return New-DiagnosticResult -Status "NOT_RUN" -Data ([ordered]@{ reason = "DISABLED" }) }
    try {
        $duration = [math]::Min([math]::Max([int]$BenchmarkConfig.durationSeconds, 2), 60)
        $sampleInterval = [math]::Min([math]::Max([int]$BenchmarkConfig.sampleIntervalSeconds, 1), $duration)
        $payload = New-Object byte[] (1MB)
        (New-Object Random 4242).NextBytes($payload)
        $sha = [Security.Cryptography.SHA256]::Create()
        $watch = [Diagnostics.Stopwatch]::StartNew()
        $hashes = 0L
        $samples = @()
        $nextSample = $sampleInterval
        try {
            while ($watch.Elapsed.TotalSeconds -lt $duration) {
                [void]$sha.ComputeHash($payload)
                $hashes++
                if ($watch.Elapsed.TotalSeconds -ge $nextSample) {
                    $samples += [ordered]@{
                        elapsedSeconds = [math]::Round($watch.Elapsed.TotalSeconds, 2)
                        cumulativeMBps = [math]::Round($hashes / $watch.Elapsed.TotalSeconds, 2)
                    }
                    $nextSample += $sampleInterval
                }
            }
        }
        finally { $sha.Dispose(); $watch.Stop() }

        New-DiagnosticResult -Status "OK" -Data ([ordered]@{
            algorithm = "SHA256 over 1 MiB buffer"
            durationSeconds = [math]::Round($watch.Elapsed.TotalSeconds, 2)
            iterations = $hashes
            throughputMBps = if ($watch.Elapsed.TotalSeconds -gt 0) { [math]::Round($hashes / $watch.Elapsed.TotalSeconds, 2) } else { $null }
            samples = $samples
        })
    }
    catch { New-DiagnosticResult -Status "ERROR" -ErrorMessage $_.Exception.Message }
}

Export-ModuleMember -Function Get-CpuPerformanceDiagnostic

