Set-StrictMode -Version 2.0

function Get-WinSATScores {
    try {
        $assessment = @(Get-CimInstance -ClassName Win32_WinSAT -ErrorAction Stop | Select-Object -First 1)[0]
        if ($null -eq $assessment) {
            return [ordered]@{
                assessmentState = $null; systemScore = $null; cpuScore = $null; memoryScore = $null
                graphicsScore = $null; d3dScore = $null; diskScore = $null; timeTaken = $null
            }
        }

        [ordered]@{
            assessmentState = Get-PropertyValue $assessment "WinSATAssessmentState"
            systemScore = Get-PropertyValue $assessment "WinSPRLevel"
            cpuScore = Get-PropertyValue $assessment "CPUScore"
            memoryScore = Get-PropertyValue $assessment "MemoryScore"
            graphicsScore = Get-PropertyValue $assessment "GraphicsScore"
            d3dScore = Get-PropertyValue $assessment "D3DScore"
            diskScore = Get-PropertyValue $assessment "DiskScore"
            timeTaken = Get-PropertyValue $assessment "TimeTaken"
        }
    }
    catch { throw }
}

function Get-WinSATDiagnostic {
    param([object]$BenchmarkConfig)

    if ($null -eq $BenchmarkConfig -or -not $BenchmarkConfig.enabled) {
        return New-DiagnosticResult -Status "NOT_RUN" -Data ([ordered]@{ reason = "DISABLED" })
    }

    $winSatPath = Join-Path $env:SystemRoot "System32\winsat.exe"
    if (-not (Test-Path -LiteralPath $winSatPath)) {
        return New-DiagnosticResult -Status "UNAVAILABLE" -Data ([ordered]@{ reason = "WINSAT_NOT_AVAILABLE" })
    }

    try {
        $timeoutSeconds = [math]::Min([math]::Max([int]$BenchmarkConfig.timeoutSeconds, 60), 1800)
        $started = (Get-Date).ToUniversalTime()
        $process = Start-Process -FilePath $winSatPath -ArgumentList "formal" -PassThru -NoNewWindow
        if (-not $process.WaitForExit($timeoutSeconds * 1000)) {
            try { $process.Kill() } catch { }
            return New-DiagnosticResult -Status "ERROR" -Data ([ordered]@{
                command = "winsat formal"; timeoutSeconds = $timeoutSeconds; startedAtUtc = $started.ToString("o")
                completedAtUtc = (Get-Date).ToUniversalTime().ToString("o"); exitCode = $null; scores = $null
            }) -ErrorMessage "WinSAT formal did not complete within $timeoutSeconds seconds."
        }

        $completed = (Get-Date).ToUniversalTime()
        $scores = Get-WinSATScores
        $hasScore = @($scores.systemScore, $scores.cpuScore, $scores.memoryScore, $scores.graphicsScore, $scores.d3dScore, $scores.diskScore | Where-Object { $null -ne $_ }).Count -gt 0
        $data = [ordered]@{
            command = "winsat formal"; timeoutSeconds = $timeoutSeconds; startedAtUtc = $started.ToString("o")
            completedAtUtc = $completed.ToString("o"); durationSeconds = [math]::Round(($completed - $started).TotalSeconds, 2)
            exitCode = $process.ExitCode; scores = $scores
        }
        if ($process.ExitCode -ne 0) {
            return New-DiagnosticResult -Status "ERROR" -Data $data -ErrorMessage "WinSAT formal exited with code $($process.ExitCode)."
        }
        if (-not $hasScore) {
            return New-DiagnosticResult -Status "UNAVAILABLE" -Data $data -ErrorMessage "WinSAT formal completed but Windows did not publish component scores."
        }
        return New-DiagnosticResult -Status "OK" -Data $data
    }
    catch { return New-DiagnosticResult -Status "ERROR" -ErrorMessage $_.Exception.Message }
}

Export-ModuleMember -Function Get-WinSATDiagnostic
