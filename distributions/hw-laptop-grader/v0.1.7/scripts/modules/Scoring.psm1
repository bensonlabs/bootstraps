Set-StrictMode -Version 2.0

function Get-ConservativeScore {
    param([object]$Diagnostics, [object]$ScoringConfig)
    $warnings = @()
    foreach ($property in $Diagnostics.PSObject.Properties) {
        $statusProperty = $property.Value.PSObject.Properties["status"]
        if ($statusProperty -and $statusProperty.Value -eq "ERROR") { $warnings += "$($property.Name): diagnostic error" }
    }

    $devicesProperty = $Diagnostics.PSObject.Properties["devices"]
    $devices = if ($devicesProperty) { $devicesProperty.Value } else { $null }
    if ($null -ne $devices -and $devices.status -eq "OK" -and $devices.data.problemDeviceCount -gt 0) {
        $warnings += "Windows reports $($devices.data.problemDeviceCount) problem device(s)."
    }
    $reliabilityProperty = $Diagnostics.PSObject.Properties["reliability"]
    $reliability = if ($reliabilityProperty) { $reliabilityProperty.Value } else { $null }
    if ($null -ne $reliability -and $reliability.status -eq "OK") {
        if ($reliability.data.whea.count -gt 0) { $warnings += "Recent WHEA hardware events were found." }
        if ($reliability.data.storage.count -gt 0) { $warnings += "Recent storage-related events were found." }
    }

    if (-not $ScoringConfig.enabled) {
        $readiness = if ($Diagnostics.PSObject.Properties["readiness"]) { $Diagnostics.readiness } else { $null }
        $recommendedRole = if ($null -ne $readiness -and $readiness.status -eq "OK") { $readiness.data.recommendedRole } else { $null }
        if ($null -ne $readiness -and $readiness.status -eq "OK") { $warnings += @($readiness.data.reasons) }
        return [pscustomobject]@{
            score = $null
            grade = "BASELINE_PENDING"
            recommendedRole = $recommendedRole
            warnings = @($warnings)
            scoringProfile = [string]$ScoringConfig.profile
        }
    }

    # No built-in fleet thresholds. Enabling scoring without a configured model
    # still preserves measurements while refusing to invent a grade.
    [pscustomobject]@{
        score = $null
        grade = "CONFIGURATION_REQUIRED"
        recommendedRole = $null
        warnings = @($warnings) + @("Scoring is enabled, but no fleet-calibrated scoring model is installed.")
        scoringProfile = [string]$ScoringConfig.profile
    }
}

Export-ModuleMember -Function Get-ConservativeScore

