Set-StrictMode -Version 2.0

function Get-NetworkSecurityDiagnostic {
    try {
        $wireless = @()
        if (Get-Command Get-NetAdapter -ErrorAction SilentlyContinue) {
            $wireless = @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object {
                $_.NdisPhysicalMedium -eq 9 -or $_.InterfaceDescription -match "Wireless|Wi-Fi|802\.11"
            } | ForEach-Object {
                [ordered]@{ name = $_.Name; description = $_.InterfaceDescription; status = $_.Status; linkSpeed = $_.LinkSpeed; macAddress = $_.MacAddress; driverVersion = $_.DriverVersion }
            })
        }

        $tpm = $null
        if (Get-Command Get-Tpm -ErrorAction SilentlyContinue) {
            try {
                $tpmValue = Get-Tpm -ErrorAction Stop
                $tpm = [ordered]@{ present = [bool]$tpmValue.TpmPresent; ready = [bool]$tpmValue.TpmReady; enabled = [bool]$tpmValue.TpmEnabled; activated = [bool]$tpmValue.TpmActivated }
            } catch { $tpm = $null }
        }

        $secureBoot = $null
        if (Get-Command Confirm-SecureBootUEFI -ErrorAction SilentlyContinue) {
            try { $secureBoot = [bool](Confirm-SecureBootUEFI -ErrorAction Stop) } catch { $secureBoot = $null }
        }

        New-DiagnosticResult -Status "OK" -Data ([ordered]@{ wifiAdapters = $wireless; tpm = $tpm; secureBootEnabled = $secureBoot })
    }
    catch { New-DiagnosticResult -Status "ERROR" -ErrorMessage $_.Exception.Message }
}

Export-ModuleMember -Function Get-NetworkSecurityDiagnostic

