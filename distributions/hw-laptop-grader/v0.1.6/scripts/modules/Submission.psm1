Set-StrictMode -Version 2.0

function Submit-GraderResult {
    param([object]$Report, [object]$SubmissionConfig)
    if (-not $SubmissionConfig.enabled) { return [pscustomobject]@{ status = "NOT_RUN"; reason = "DISABLED"; response = $null } }
    if ([string]::IsNullOrWhiteSpace([string]$SubmissionConfig.endpoint)) { return [pscustomobject]@{ status = "UNAVAILABLE"; reason = "ENDPOINT_NOT_CONFIGURED"; response = $null } }
    try {
        $uri = [string]$SubmissionConfig.endpoint
        $tokenName = [string]$SubmissionConfig.tokenEnvironmentVariable
        $token = if (-not [string]::IsNullOrWhiteSpace($tokenName)) { [Environment]::GetEnvironmentVariable($tokenName) } else { $null }
        if (-not [string]::IsNullOrWhiteSpace($token)) {
            $separator = if ($uri.Contains("?")) { "&" } else { "?" }
            $uri = "$uri$separator$([Uri]::EscapeDataString([string]$SubmissionConfig.tokenQueryParameter))=$([Uri]::EscapeDataString($token))"
        }
        $response = Invoke-RestMethod -Uri $uri -Method Post -ContentType "application/json; charset=utf-8" -Body ($Report | ConvertTo-Json -Depth 12 -Compress) -TimeoutSec ([int]$SubmissionConfig.timeoutSeconds) -ErrorAction Stop
        [pscustomobject]@{ status = "OK"; reason = $null; response = $response }
    }
    catch { [pscustomobject]@{ status = "ERROR"; reason = $_.Exception.Message; response = $null } }
}

Export-ModuleMember -Function Submit-GraderResult
