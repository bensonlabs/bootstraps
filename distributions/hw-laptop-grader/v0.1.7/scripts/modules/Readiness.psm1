Set-StrictMode -Version 2.0

function Get-ReadinessValue {
    param([object]$Object, [string[]]$Path)
    $value = $Object
    foreach ($part in $Path) {
        if ($null -eq $value) { return $null }
        $value = Get-PropertyValue $value $part
    }
    return $value
}

function Get-ReadinessGraphics {
    try {
        $adapters = @(Get-CimInstance -ClassName Win32_VideoController -ErrorAction Stop | ForEach-Object {
            [ordered]@{
                name = Get-PropertyValue $_ "Name"
                driverVersion = Get-PropertyValue $_ "DriverVersion"
                videoProcessor = Get-PropertyValue $_ "VideoProcessor"
                currentResolution = if ((Get-PropertyValue $_ "CurrentHorizontalResolution") -and (Get-PropertyValue $_ "CurrentVerticalResolution")) { "{0}x{1}" -f (Get-PropertyValue $_ "CurrentHorizontalResolution"), (Get-PropertyValue $_ "CurrentVerticalResolution") } else { $null }
            }
        })
        $displays = @(Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorBasicDisplayParams -ErrorAction SilentlyContinue)
        return [ordered]@{ adapters = $adapters; displayCount = $displays.Count }
    }
    catch { return [ordered]@{ adapters = @(); displayCount = $null; error = $_.Exception.Message } }
}

function Get-ReadinessSystemDrive {
    try {
        $drive = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$($env:SystemDrive)'" -ErrorAction Stop
        return [ordered]@{
            deviceId = Get-PropertyValue $drive "DeviceID"
            freeGB = if ($null -ne (Get-PropertyValue $drive "FreeSpace")) { [math]::Round(([double](Get-PropertyValue $drive "FreeSpace") / 1GB), 2) } else { $null }
            sizeGB = if ($null -ne (Get-PropertyValue $drive "Size")) { [math]::Round(([double](Get-PropertyValue $drive "Size") / 1GB), 2) } else { $null }
        }
    }
    catch { return [ordered]@{ deviceId = $env:SystemDrive; freeGB = $null; sizeGB = $null; error = $_.Exception.Message } }
}

function Get-ReadinessBitLocker {
    if (-not (Get-Command Get-BitLockerVolume -ErrorAction SilentlyContinue)) {
        return [ordered]@{ status = "UNAVAILABLE"; protectionStatus = $null; volumeStatus = $null; reason = "BITLOCKER_CMDLET_NOT_AVAILABLE" }
    }
    try {
        $volume = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop
        $protection = Get-PropertyValue $volume "ProtectionStatus"
        return [ordered]@{
            status = if ([string]$protection -eq "On" -or [string]$protection -eq "1") { "ON" } else { "OFF" }
            protectionStatus = [string]$protection
            volumeStatus = [string](Get-PropertyValue $volume "VolumeStatus")
        }
    }
    catch { return [ordered]@{ status = "UNAVAILABLE"; protectionStatus = $null; volumeStatus = $null; error = $_.Exception.Message } }
}

function Get-ReadinessDevicePresence {
    try {
        $pnp = if (Get-Command Get-PnpDevice -ErrorAction SilentlyContinue) { @(Get-PnpDevice -PresentOnly -ErrorAction Stop) } else { @() }
        $camera = @($pnp | Where-Object { $_.Class -in @("Camera", "Image") -or $_.FriendlyName -match "camera|webcam" })
        $touchpad = @($pnp | Where-Object { $_.FriendlyName -match "touchpad|precision touch" })
        $keyboard = @(Get-CimInstance -ClassName Win32_Keyboard -ErrorAction SilentlyContinue)
        $audio = @(Get-CimInstance -ClassName Win32_SoundDevice -ErrorAction SilentlyContinue)
        $wifi = @($pnp | Where-Object { $_.FriendlyName -match "wi-?fi|wireless|802\.11" })
        return [ordered]@{
            cameraDetected = $camera.Count -gt 0
            audioDetected = $audio.Count -gt 0
            keyboardDetected = $keyboard.Count -gt 0
            touchpadDetected = if ($touchpad.Count -gt 0) { $true } else { $null }
            wifiDetected = $wifi.Count -gt 0
        }
    }
    catch { return [ordered]@{ cameraDetected = $null; audioDetected = $null; keyboardDetected = $null; touchpadDetected = $null; wifiDetected = $null; error = $_.Exception.Message } }
}

function Get-ReadinessDiagnostic {
    param([object]$Diagnostics, [object]$ReadinessConfig)

    try {
        $graphics = Get-ReadinessGraphics
        $systemDrive = Get-ReadinessSystemDrive
        $bitLocker = Get-ReadinessBitLocker
        $devicePresence = Get-ReadinessDevicePresence
        $manualChecksRequired = @("Camera video", "Microphone input", "Speakers", "Keyboard", "Touchpad", "Wi-Fi connection", "AC charging")
        $reasons = @()

        $batteries = @(Get-ReadinessValue $Diagnostics @("battery", "data", "batteries"))
        $batteryHealth = if ($batteries.Count -gt 0) { Get-PropertyValue $batteries[0] "healthPct" } else { $null }
        $diskHealth = @(Get-ReadinessValue $Diagnostics @("storage", "data", "disks") | ForEach-Object { Get-PropertyValue $_ "healthStatus" })
        $activation = Get-ReadinessValue $Diagnostics @("windowsHealth", "data", "activation", "activationStatus")
        $problemDevices = Get-ReadinessValue $Diagnostics @("devices", "data", "problemDeviceCount")
        $whea = Get-ReadinessValue $Diagnostics @("reliability", "data", "whea", "count")
        $storageEvents = Get-ReadinessValue $Diagnostics @("reliability", "data", "storage", "count")
        $minimumFreeGB = [double]$ReadinessConfig.minimumFreeSystemDriveGB
        $minimumBatteryHealthPct = [double]$ReadinessConfig.minimumBatteryHealthPct

        if ($null -ne $batteryHealth -and [double]$batteryHealth -lt $minimumBatteryHealthPct) { $reasons += "Battery health below $minimumBatteryHealthPct%." }
        if (@($diskHealth | Where-Object { $_ -and $_ -ne "Healthy" }).Count -gt 0) { $reasons += "Storage health needs review." }
        if ($null -ne $systemDrive.freeGB -and [double]$systemDrive.freeGB -lt $minimumFreeGB) { $reasons += "System drive free space below $minimumFreeGB GB." }
        if ($activation -and $activation -ne "LICENSED") { $reasons += "Windows activation is $activation." }
        if ($null -ne $problemDevices -and [int]$problemDevices -gt 0) { $reasons += "Windows reports $problemDevices problem device(s)." }
        if ($null -ne $whea -and [int]$whea -gt 0) { $reasons += "Recent WHEA hardware events were found." }
        if ($null -ne $storageEvents -and [int]$storageEvents -gt 0) { $reasons += "Recent storage-related events were found." }
        if ($ReadinessConfig.requireBitLockerForAssignment -and $bitLocker.status -ne "ON") { $reasons += "BitLocker protection is not confirmed on." }

        $candidateRoles = @()
        $decision = "NEEDS_REVIEW"
        if ($reasons.Count -eq 0) {
            $candidateRoles = @("Student cart loaner", "Faculty/staff loaner")
            if ($devicePresence.cameraDetected -and $devicePresence.audioDetected) { $candidateRoles += "Zoom loaner" }
            $decision = "MANUAL_VALIDATION_REQUIRED"
        }

        New-DiagnosticResult -Status "OK" -Data ([ordered]@{
            decision = $decision
            recommendedRole = $decision
            candidateRoles = $candidateRoles
            reasons = $reasons
            graphics = $graphics
            systemDrive = $systemDrive
            bitLocker = $bitLocker
            devicePresence = $devicePresence
            manualChecksRequired = $manualChecksRequired
        })
    }
    catch { New-DiagnosticResult -Status "ERROR" -ErrorMessage $_.Exception.Message }
}

Export-ModuleMember -Function Get-ReadinessDiagnostic
