Set-StrictMode -Version 2.0

function Get-DevicesDiagnostic {
    try {
        $problemDevices = @()
        if (Get-Command Get-PnpDevice -ErrorAction SilentlyContinue) {
            $problemDevices = @(Get-PnpDevice -PresentOnly -ErrorAction Stop | Where-Object { $_.Status -ne "OK" } | ForEach-Object {
                [ordered]@{ class = $_.Class; friendlyName = $_.FriendlyName; instanceId = $_.InstanceId; status = $_.Status; problem = Get-PropertyValue $_ "Problem" }
            })
        }
        else {
            $problemDevices = @(Get-CimInstance Win32_PnPEntity -ErrorAction Stop | Where-Object { $null -ne $_.ConfigManagerErrorCode -and $_.ConfigManagerErrorCode -ne 0 } | ForEach-Object {
                [ordered]@{ class = $_.PNPClass; friendlyName = $_.Name; instanceId = $_.PNPDeviceID; status = $_.Status; problem = $_.ConfigManagerErrorCode }
            })
        }
        New-DiagnosticResult -Status "OK" -Data ([ordered]@{ problemDeviceCount = $problemDevices.Count; problemDevices = $problemDevices })
    }
    catch { New-DiagnosticResult -Status "ERROR" -ErrorMessage $_.Exception.Message }
}

Export-ModuleMember -Function Get-DevicesDiagnostic

