Set-StrictMode -Version 2.0

function Get-HardwareInventoryDiagnostic {
    try {
        $system = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
        $product = Get-CimInstance -ClassName Win32_ComputerSystemProduct -ErrorAction SilentlyContinue
        $bios = Get-CimInstance -ClassName Win32_BIOS -ErrorAction SilentlyContinue
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
        $cpu = @(Get-CimInstance -ClassName Win32_Processor -ErrorAction SilentlyContinue)
        $memory = @(Get-CimInstance -ClassName Win32_PhysicalMemory -ErrorAction SilentlyContinue)

        $totalMemoryBytes = $null
        if ($null -ne $system.TotalPhysicalMemory) { $totalMemoryBytes = [long]$system.TotalPhysicalMemory }

        $data = [ordered]@{
            computerName = [string]$env:COMPUTERNAME
            manufacturer = Get-PropertyValue $system "Manufacturer"
            model = Get-PropertyValue $system "Model"
            serialNumber = Get-PropertyValue $bios "SerialNumber"
            systemUuid = Get-PropertyValue $product "UUID"
            biosVersion = Get-PropertyValue $bios "SMBIOSBIOSVersion"
            biosDateUtc = ConvertTo-IsoDateOrNull (Get-PropertyValue $bios "ReleaseDate")
            windowsCaption = Get-PropertyValue $os "Caption"
            windowsVersion = Get-PropertyValue $os "Version"
            windowsBuildNumber = Get-PropertyValue $os "BuildNumber"
            windowsInstallDateUtc = ConvertTo-IsoDateOrNull (Get-PropertyValue $os "InstallDate")
            cpu = @($cpu | ForEach-Object {
                [ordered]@{
                    model = Get-PropertyValue $_ "Name"
                    physicalCores = Get-PropertyValue $_ "NumberOfCores"
                    logicalCores = Get-PropertyValue $_ "NumberOfLogicalProcessors"
                    maxClockMHz = Get-PropertyValue $_ "MaxClockSpeed"
                    currentClockMHz = Get-PropertyValue $_ "CurrentClockSpeed"
                }
            })
            memory = [ordered]@{
                totalBytes = $totalMemoryBytes
                totalGB = if ($null -ne $totalMemoryBytes) { [math]::Round($totalMemoryBytes / 1GB, 2) } else { $null }
                dimmCount = $memory.Count
                modules = @($memory | ForEach-Object {
                    [ordered]@{
                        manufacturer = Get-PropertyValue $_ "Manufacturer"
                        partNumber = if ($null -ne $_.PartNumber) { ([string]$_.PartNumber).Trim() } else { $null }
                        capacityBytes = Get-PropertyValue $_ "Capacity"
                        configuredSpeedMHz = Get-PropertyValue $_ "ConfiguredClockSpeed"
                        ratedSpeedMHz = Get-PropertyValue $_ "Speed"
                    }
                })
            }
        }

        New-DiagnosticResult -Status "OK" -Data $data
    }
    catch {
        New-DiagnosticResult -Status "ERROR" -ErrorMessage $_.Exception.Message
    }
}

Export-ModuleMember -Function Get-HardwareInventoryDiagnostic

