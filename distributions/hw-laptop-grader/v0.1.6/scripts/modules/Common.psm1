Set-StrictMode -Version 2.0

function New-DiagnosticResult {
    param(
        [ValidateSet("OK", "UNAVAILABLE", "ERROR", "NOT_RUN")][string]$Status,
        [AllowNull()][object]$Data = $null,
        [AllowNull()][string]$ErrorMessage = $null
    )

    [pscustomobject]@{
        status = $Status
        collectedAtUtc = (Get-Date).ToUniversalTime().ToString("o")
        data = $Data
        error = $ErrorMessage
    }
}

function Get-PropertyValue {
    param(
        [AllowNull()][object]$InputObject,
        [Parameter(Mandatory = $true)][string]$Name
    )

    if ($null -eq $InputObject) { return $null }
    $property = $InputObject.PSObject.Properties[$Name]
    if ($property) { return $property.Value }
    return $null
}

function ConvertTo-NullableInt64 {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return $null }
    $parsed = 0L
    if ([long]::TryParse(([string]$Value -replace '[^0-9-]', ''), [ref]$parsed)) { return $parsed }
    return $null
}

function ConvertTo-IsoDateOrNull {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) { return $null }
    try { return ([System.Management.ManagementDateTimeConverter]::ToDateTime([string]$Value)).ToUniversalTime().ToString("o") }
    catch {
        try { return ([datetime]$Value).ToUniversalTime().ToString("o") }
        catch { return $null }
    }
}

Export-ModuleMember -Function New-DiagnosticResult, Get-PropertyValue, ConvertTo-NullableInt64, ConvertTo-IsoDateOrNull

