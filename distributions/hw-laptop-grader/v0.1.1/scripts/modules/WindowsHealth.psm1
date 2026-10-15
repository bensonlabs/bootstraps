Set-StrictMode -Version 2.0

function Get-WindowsPowerState {
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        $power = [System.Windows.Forms.SystemInformation]::PowerStatus
        [ordered]@{
            status = "OK"
            powerLineStatus = [string]$power.PowerLineStatus
            batteryChargePct = if ($power.BatteryLifePercent -ge 0) { [math]::Round($power.BatteryLifePercent * 100, 1) } else { $null }
            batteryLifeRemainingSeconds = if ($power.BatteryLifeRemaining -ge 0) { [int]$power.BatteryLifeRemaining } else { $null }
        }
    }
    catch { [ordered]@{ status = "UNAVAILABLE"; powerLineStatus = $null; batteryChargePct = $null; batteryLifeRemainingSeconds = $null; error = $_.Exception.Message } }
}

function Get-WindowsThermalState {
    try {
        $zones = @(Get-CimInstance -Namespace root/wmi -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction Stop | ForEach-Object {
            $current = Get-PropertyValue $_ "CurrentTemperature"
            $critical = Get-PropertyValue $_ "CriticalTripPoint"
            [ordered]@{
                name = Get-PropertyValue $_ "InstanceName"
                currentTemperatureC = if ($null -ne $current) { [math]::Round((([double]$current / 10) - 273.15), 1) } else { $null }
                criticalTemperatureC = if ($null -ne $critical) { [math]::Round((([double]$critical / 10) - 273.15), 1) } else { $null }
            }
        })
        if ($zones.Count -eq 0) { return [ordered]@{ status = "UNAVAILABLE"; zones = @(); reason = "NO_ACPI_THERMAL_ZONES" } }
        [ordered]@{ status = "OK"; zones = $zones }
    }
    catch { [ordered]@{ status = "UNAVAILABLE"; zones = @(); error = $_.Exception.Message } }
}

function Get-WindowsMemoryDiagnosticResult {
    try {
        $event = Get-WinEvent -FilterHashtable @{ LogName = "System"; ProviderName = "Microsoft-Windows-MemoryDiagnostics-Results" } -MaxEvents 1 -ErrorAction Stop
        if ($null -eq $event) { return [ordered]@{ status = "UNAVAILABLE"; reason = "NO_COMPLETED_WINDOWS_MEMORY_DIAGNOSTIC"; lastRunUtc = $null; eventId = $null; message = $null } }
        [ordered]@{
            status = "OK"
            lastRunUtc = $event.TimeCreated.ToUniversalTime().ToString("o")
            eventId = $event.Id
            message = $event.Message
        }
    }
    catch { [ordered]@{ status = "UNAVAILABLE"; lastRunUtc = $null; eventId = $null; message = $null; error = $_.Exception.Message } }
}

function Get-WindowsHealthDiagnostic {
    try {
        New-DiagnosticResult -Status "OK" -Data ([ordered]@{
            coverage = "WINDOWS_BEST_EFFORT_NOT_DELL_EPSA"
            power = Get-WindowsPowerState
            thermal = Get-WindowsThermalState
            memoryDiagnostic = Get-WindowsMemoryDiagnosticResult
        })
    }
    catch { New-DiagnosticResult -Status "ERROR" -ErrorMessage $_.Exception.Message }
}

Export-ModuleMember -Function Get-WindowsHealthDiagnostic
