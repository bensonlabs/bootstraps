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

function Get-WindowsPowerPlan {
    try {
        $activePlan = @(Get-CimInstance -Namespace root\\cimv2\\power -ClassName Win32_PowerPlan -ErrorAction Stop | Where-Object { $_.IsActive }) | Select-Object -First 1
        if ($null -ne $activePlan) {
            $instanceId = [string](Get-PropertyValue $activePlan "InstanceID")
            $guidMatch = [regex]::Match($instanceId, '[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}')
            return [ordered]@{
                status = "OK"
                activePlanName = [string](Get-PropertyValue $activePlan "ElementName")
                activePlanGuid = if ($guidMatch.Success) { $guidMatch.Value.ToLowerInvariant() } else { $null }
                source = "Win32_PowerPlan"
            }
        }
    }
    catch { }

    try {
        $output = @(powercfg /getactivescheme 2>&1)
        $text = ($output -join " ").Trim()
        $guidMatch = [regex]::Match($text, '[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}')
        $nameMatch = [regex]::Match($text, '\((?<name>[^)]+)\)')
        if ($guidMatch.Success -or $nameMatch.Success) {
            return [ordered]@{
                status = "OK"
                activePlanName = if ($nameMatch.Success) { $nameMatch.Groups['name'].Value } else { $null }
                activePlanGuid = if ($guidMatch.Success) { $guidMatch.Value.ToLowerInvariant() } else { $null }
                source = "powercfg"
            }
        }
        return [ordered]@{ status = "UNAVAILABLE"; activePlanName = $null; activePlanGuid = $null; reason = "NO_ACTIVE_POWER_PLAN_REPORTED" }
    }
    catch { [ordered]@{ status = "UNAVAILABLE"; activePlanName = $null; activePlanGuid = $null; error = $_.Exception.Message } }
}

function Get-WindowsActivationState {
    try {
        $products = @(Get-CimInstance -ClassName SoftwareLicensingProduct -Filter "ApplicationID='55c92734-d682-4d71-983e-d6ec3f16059f'" -ErrorAction Stop |
            Where-Object {
                $name = [string](Get-PropertyValue $_ "Name")
                $partialKey = Get-PropertyValue $_ "PartialProductKey"
                $name -match '^Windows' -and -not [string]::IsNullOrWhiteSpace([string]$partialKey)
            })
        $product = @($products | Where-Object { (Get-PropertyValue $_ "LicenseStatus") -eq 1 } | Select-Object -First 1)[0]
        if ($null -eq $product) { $product = @($products | Select-Object -First 1)[0] }
        if ($null -eq $product) { return [ordered]@{ status = "UNAVAILABLE"; activationStatus = $null; licenseStatusCode = $null; licenseChannel = $null; reason = "NO_WINDOWS_LICENSE_PRODUCT_FOUND" } }

        $licenseStatusCode = [int](Get-PropertyValue $product "LicenseStatus")
        $description = [string](Get-PropertyValue $product "Description")
        $licenseChannel = if ($description -match 'VOLUME') { "VOLUME" } elseif ($description -match 'OEM') { "OEM" } elseif ($description -match 'RETAIL') { "RETAIL" } else { "UNKNOWN" }
        $statusNames = @{
            0 = "UNLICENSED"
            1 = "LICENSED"
            2 = "OOB_GRACE"
            3 = "OUT_OF_TOLERANCE_GRACE"
            4 = "NON_GENUINE_GRACE"
            5 = "NOTIFICATION"
            6 = "EXTENDED_GRACE"
        }
        [ordered]@{
            status = "OK"
            activationStatus = if ($statusNames.ContainsKey($licenseStatusCode)) { $statusNames[$licenseStatusCode] } else { "UNKNOWN" }
            licenseStatusCode = $licenseStatusCode
            licenseChannel = $licenseChannel
        }
    }
    catch { [ordered]@{ status = "UNAVAILABLE"; activationStatus = $null; licenseStatusCode = $null; licenseChannel = $null; error = $_.Exception.Message } }
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
            powerPlan = Get-WindowsPowerPlan
            activation = Get-WindowsActivationState
            thermal = Get-WindowsThermalState
            memoryDiagnostic = Get-WindowsMemoryDiagnosticResult
        })
    }
    catch { New-DiagnosticResult -Status "ERROR" -ErrorMessage $_.Exception.Message }
}

Export-ModuleMember -Function Get-WindowsHealthDiagnostic
