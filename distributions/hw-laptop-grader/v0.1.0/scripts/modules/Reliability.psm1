Set-StrictMode -Version 2.0

function Get-EventCountAndSamples {
    param([string]$LogName, [int[]]$Ids, [datetime]$StartTime, [string[]]$Providers = @())
    try {
        $filter = @{ LogName = $LogName; StartTime = $StartTime }
        if ($Ids.Count -gt 0) { $filter.Id = $Ids }
        $events = @(Get-WinEvent -FilterHashtable $filter -ErrorAction Stop | Where-Object {
            $Providers.Count -eq 0 -or $_.ProviderName -in $Providers
        })
        [ordered]@{
            status = "OK"
            count = $events.Count
            samples = @($events | Select-Object -First 10 | ForEach-Object {
                [ordered]@{ timeCreatedUtc = $_.TimeCreated.ToUniversalTime().ToString("o"); id = $_.Id; provider = $_.ProviderName; level = $_.LevelDisplayName; message = $_.Message }
            })
        }
    }
    catch { [ordered]@{ status = "UNAVAILABLE"; count = $null; samples = @(); error = $_.Exception.Message } }
}

function Get-ReliabilityDiagnostic {
    param([int]$LookbackDays)
    try {
        $days = [math]::Min([math]::Max($LookbackDays, 1), 365)
        $start = (Get-Date).AddDays(-$days)
        $data = [ordered]@{
            lookbackDays = $days
            whea = Get-EventCountAndSamples -LogName "System" -Ids @(1, 17, 18, 19, 20, 46, 47) -StartTime $start -Providers @("Microsoft-Windows-WHEA-Logger")
            storage = Get-EventCountAndSamples -LogName "System" -Ids @(7, 51, 55, 129, 153, 157) -StartTime $start
            unexpectedShutdowns = Get-EventCountAndSamples -LogName "System" -Ids @(41, 6008) -StartTime $start
        }
        New-DiagnosticResult -Status "OK" -Data $data
    }
    catch { New-DiagnosticResult -Status "ERROR" -ErrorMessage $_.Exception.Message }
}

Export-ModuleMember -Function Get-ReliabilityDiagnostic
