Set-StrictMode -Version 2.0

function Get-BatteryValue {
    param([object]$Battery, [string[]]$Names)
    foreach ($name in $Names) {
        $value = Get-PropertyValue -InputObject $Battery -Name $name
        if ($null -ne $value -and -not [string]::IsNullOrWhiteSpace([string]$value)) { return $value }
    }
    return $null
}

function Get-BatteryDiagnostic {
    $reportPath = Join-Path $env:TEMP ("hw-laptop-battery-{0}.xml" -f [guid]::NewGuid().ToString("N"))
    try {
        $batteryCim = @(Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue)
        if ($batteryCim.Count -eq 0) {
            return New-DiagnosticResult -Status "UNAVAILABLE" -Data ([ordered]@{
                batteryPresent = $false
                reason = "NO_BATTERY"
                batteries = @()
            })
        }

        $quotedReportPath = '"{0}"' -f ($reportPath -replace '"', '\"')
        $process = Start-Process -FilePath "powercfg.exe" -ArgumentList @("/batteryreport", "/output", $quotedReportPath, "/xml") -Wait -PassThru -WindowStyle Hidden
        if ($process.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $reportPath)) {
            throw "powercfg battery report failed with exit code $($process.ExitCode)."
        }

        [xml]$report = Get-Content -LiteralPath $reportPath -Raw -ErrorAction Stop
        $batteryNodes = @($report.BatteryReport.Batteries.Battery)
        if ($batteryNodes.Count -eq 0 -or $null -eq $batteryNodes[0]) {
            return New-DiagnosticResult -Status "UNAVAILABLE" -Data ([ordered]@{
                batteryPresent = $true
                reason = "REPORT_DATA_UNAVAILABLE"
                batteries = @()
            })
        }

        $batteries = @($batteryNodes | ForEach-Object {
            $design = ConvertTo-NullableInt64 (Get-BatteryValue $_ @("DesignCapacity", "DesignCapacity_mWh"))
            $full = ConvertTo-NullableInt64 (Get-BatteryValue $_ @("FullChargeCapacity", "FullChargeCapacity_mWh"))
            $health = $null
            if ($null -ne $design -and $design -gt 0 -and $null -ne $full) {
                $health = [math]::Round(($full / $design) * 100, 1)
            }
            [ordered]@{
                manufacturer = Get-BatteryValue $_ @("Manufacturer")
                serialNumber = Get-BatteryValue $_ @("SerialNumber", "Serial")
                chemistry = Get-BatteryValue $_ @("Chemistry")
                designCapacityMWh = $design
                fullChargeCapacityMWh = $full
                healthPct = $health
                cycleCount = ConvertTo-NullableInt64 (Get-BatteryValue $_ @("CycleCount"))
            }
        })

        New-DiagnosticResult -Status "OK" -Data ([ordered]@{ batteryPresent = $true; batteries = $batteries })
    }
    catch {
        New-DiagnosticResult -Status "ERROR" -Data ([ordered]@{ batteryPresent = $null; batteries = @() }) -ErrorMessage $_.Exception.Message
    }
    finally {
        if (Test-Path -LiteralPath $reportPath) { Remove-Item -LiteralPath $reportPath -Force -ErrorAction SilentlyContinue }
    }
}

Export-ModuleMember -Function Get-BatteryDiagnostic
