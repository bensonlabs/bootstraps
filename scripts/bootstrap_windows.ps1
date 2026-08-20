# ==============================================================================
# UNATTENDED AI DEVELOPMENT ENVIRONMENT BOOTSTRAP - WINDOWS 11
# ==============================================================================
#
# Every install step is guarded by an existence check, so the script is safe to
# re-run. Two switches make repeated runs cheap:
#
#   .\bootstrap_windows.ps1                        Full run, ends in a reboot
#   .\bootstrap_windows.ps1 -NoReboot -SkipWsl     Iterate without rebooting
#   .\bootstrap_windows.ps1 -KeepLogs 10           Keep more history
#
# Must be run from an elevated session.
# ==============================================================================

[CmdletBinding()]
param(
    # Skip the reboot at the end of a successful run.
    [switch]$NoReboot,

    # Skip Stage 5 entirely: no WSL provisioner is generated and no RunOnce
    # entry is registered.
    [switch]$SkipWsl,

    # How many bootstrap logs to retain in the user profile.
    [ValidateRange(1, 100)]
    [int]$KeepLogs = 5
)

$ErrorActionPreference = 'Stop'
Set-ExecutionPolicy RemoteSigned -Scope Process -Force
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$BootstrapLog = "$env:USERPROFILE\bootstrap_windows_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$Warnings = [System.Collections.Generic.List[string]]::new()
$Successes = [System.Collections.Generic.List[string]]::new()
$OsVersion = (Get-CimInstance Win32_OperatingSystem).Caption
$PwshVersion = "7.6.5"
$PythonVersion = "3.13"
$PythonShortVersion = $PythonVersion -replace "\.", ""
$SysinternalsPath = "$env:ProgramFiles\Sysinternals"
$FatalError = $false
$WslStageRegistered = $false

# Resolve the Desktop through the shell API rather than assuming
# "$env:USERPROFILE\Desktop". With OneDrive Known Folder Move enabled the real
# Desktop lives under the OneDrive root and the literal path does not exist,
# which previously killed Stage 5 outright.
$DesktopPath = [Environment]::GetFolderPath('Desktop')
if ([string]::IsNullOrWhiteSpace($DesktopPath)) {
    $DesktopPath = $env:USERPROFILE
}
$WslScriptPath = Join-Path $DesktopPath "wsl_bootstrap.ps1"

function Write-Log {
    param([string]$Message)
    Write-Host $Message
    Add-Content -Path $BootstrapLog -Value $Message -ErrorAction SilentlyContinue
}

function Record-Success {
    param([string]$Description)
    $Successes.Add($Description)
    Write-Log "OK: $Description"
}

function Add-Warning {
    param([string]$Message)
    $Warnings.Add($Message)
    Write-Log "WARN: $Message"
}

function Set-Fatal {
    param([string]$Message)
    $script:FatalError = $true
    $Warnings.Add("FATAL: $Message")
    Write-Log "FATAL: $Message"
}

function Print-Stage {
    param([string]$Title)
    $line = "=" * 78
    Write-Log $line
    Write-Log " $Title"
    Write-Log $line
}

function Invoke-RequiredStep {
    param([string]$Description, [scriptblock]$ScriptBlock)
    try {
        $output = & $ScriptBlock 2>&1
        if ($null -ne $output) {
            Add-Content -Path $BootstrapLog -Value ($output | Out-String).TrimEnd() -ErrorAction SilentlyContinue
        }
        if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
            Set-Fatal "$Description exited with code $LASTEXITCODE"
            return $false
        }
        Record-Success $Description
        return $true
    } catch {
        Set-Fatal "$Description failed: $($_.Exception.Message)"
        return $false
    }
}

function Invoke-OptionalStep {
    param([string]$Description, [scriptblock]$ScriptBlock)
    try {
        $output = & $ScriptBlock 2>&1
        if ($null -ne $output) {
            Add-Content -Path $BootstrapLog -Value ($output | Out-String).TrimEnd() -ErrorAction SilentlyContinue
        }
        if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
            Add-Warning "$Description exited with code $LASTEXITCODE; continuing"
        } else {
            Record-Success $Description
        }
    } catch {
        Add-Warning "$Description failed; continuing: $($_.Exception.Message)"
    }
}

function Remove-OldLogs {
    param([string]$Filter, [int]$Keep)
    try {
        $logs = @(Get-ChildItem -Path $env:USERPROFILE -Filter $Filter -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending)
        if ($logs.Count -le $Keep) {
            return
        }
        $stale = @($logs | Select-Object -Skip $Keep)
        foreach ($item in $stale) {
            Remove-Item -Path $item.FullName -Force -ErrorAction SilentlyContinue
        }
        Record-Success "Pruned $($stale.Count) old log(s) matching $Filter, keeping newest $Keep"
    } catch {
        Add-Warning "Log pruning for $Filter failed; continuing: $($_.Exception.Message)"
    }
}

function Test-CommandExists {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Test-WingetPackageInstalled {
    param([string]$Id)
    try {
        $output = & winget list --id $Id -e --accept-source-agreements 2>&1 | Out-String
        Add-Content -Path $BootstrapLog -Value $output.TrimEnd() -ErrorAction SilentlyContinue
        return ($output -match [regex]::Escape($Id)) -and ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

function Invoke-WingetInstall {
    param(
        [string]$Description,
        [string]$Id,
        [string]$Source = "winget"
    )

    if (Test-WingetPackageInstalled -Id $Id) {
        Record-Success "$Description already installed"
        return
    }

    $wingetArgs = @("install", "--id", $Id, "-e", "--accept-package-agreements", "--accept-source-agreements")
    if ($Source -ne "winget") {
        $wingetArgs += @("--source", $Source)
    }
    try {
        $output = & winget @wingetArgs 2>&1
        Add-Content -Path $BootstrapLog -Value ($output | Out-String).TrimEnd() -ErrorAction SilentlyContinue
        if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq -1978335189) {
            Record-Success "Installed: $Description"
        } else {
            Add-Warning "winget install $Description exited with code $LASTEXITCODE; continuing"
        }
    } catch {
        Add-Warning "Failed to install $Description; continuing: $($_.Exception.Message)"
    }
}

function Refresh-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    Record-Success "Refreshed PATH"
}

function Add-MachinePathEntry {
    param([string]$Directory)
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $entries = $machinePath -split ';' | Where-Object { $_ -ne '' }
    if ($entries -notcontains $Directory) {
        [Environment]::SetEnvironmentVariable("Path", (($entries + $Directory) -join ';'), "Machine")
    }
}

function Test-PowerToysInstalled {
    $paths = @(
        "$env:ProgramFiles\PowerToys\PowerToys.exe",
        "$env:LOCALAPPDATA\PowerToys\PowerToys.exe"
    )
    foreach ($path in $paths) {
        if (Test-Path $path) { return $true }
    }
    return $false
}

function Get-Pwsh7Path {
    return "$env:ProgramFiles\PowerShell\7\pwsh.exe"
}

function Test-Pwsh7Installed {
    return Test-Path (Get-Pwsh7Path)
}

function Test-SysinternalsInstalled {
    return Test-Path (Join-Path $SysinternalsPath "procexp64.exe")
}

function Test-NpmGlobalInstalled {
    param([string]$PackageName)
    try {
        $output = & npm list -g $PackageName --depth=0 2>&1 | Out-String
        Add-Content -Path $BootstrapLog -Value $output.TrimEnd() -ErrorAction SilentlyContinue
        return $output -match [regex]::Escape($PackageName)
    } catch {
        return $false
    }
}

function Install-NpmCliIfMissing {
    param(
        [string]$Description,
        [string]$CommandName,
        [string]$PackageName,
        [scriptblock]$InstallScript
    )

    if (Test-CommandExists $CommandName) {
        Record-Success "$Description already installed"
        return
    }

    if (Test-NpmGlobalInstalled $PackageName) {
        Record-Success "$Description package already installed"
        Refresh-Path
        return
    }

    Invoke-OptionalStep "Install $Description" $InstallScript
    Refresh-Path
}

function Test-AdminSession {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-WingetAvailable {
    return Test-CommandExists "winget"
}

function Invoke-PreflightChecks {
    if (-not (Test-AdminSession)) {
        Set-Fatal "This script must be run from an elevated PowerShell session"
        return $false
    }

    if (-not (Test-WingetAvailable)) {
        Set-Fatal "winget is not available on this system"
        return $false
    }

    if (-not (Invoke-RequiredStep "Verify network connectivity" {
        while (!(Test-Connection -ComputerName 8.8.8.8 -Count 1 -ErrorAction SilentlyContinue)) {
            Write-Log "Waiting for network connectivity..."
            Start-Sleep -Seconds 3
        }
    })) {
        return $false
    }

    Record-Success "Windows bootstrap preflight passed"
    return $true
}

function Print-Summary {
    Write-Log ""
    $line = "=" * 78
    Write-Log $line
    Write-Log " FINAL SUMMARY"
    Write-Log $line
    Write-Log "Log file: $BootstrapLog"
    Write-Log "OS: $OsVersion"
    Write-Log "Host PowerShell: $($PSVersionTable.PSVersion)"
    Write-Log "Desktop: $DesktopPath"
    Write-Log "Mode: NoReboot=$NoReboot SkipWsl=$SkipWsl KeepLogs=$KeepLogs"
    Write-Log "Successful steps: $($Successes.Count)"
    Write-Log "Warnings: $($Warnings.Count)"
    Write-Log "Fatal error state: $FatalError"
    Write-Log ""
    Write-Log "Successful items:"
    foreach ($item in $Successes) { Write-Log "  - $item" }
    if ($Warnings.Count -gt 0) {
        Write-Log ""
        Write-Log "Warnings encountered:"
        foreach ($item in $Warnings) { Write-Log "  - $item" }
        Write-Log ""
        Write-Log "Review the full log at: $BootstrapLog"
    } else {
        Write-Log ""
        Write-Log "No warnings encountered."
    }
}

Write-Log ("=" * 78)
Write-Log " WINDOWS AI DEV BOOTSTRAP"
Write-Log " Log file: $BootstrapLog"
Write-Log " OS: $OsVersion"
Write-Log " Host PowerShell: $($PSVersionTable.PSVersion)"
Write-Log " Desktop: $DesktopPath"
Write-Log " Mode: NoReboot=$NoReboot SkipWsl=$SkipWsl KeepLogs=$KeepLogs"
Write-Log ("=" * 78)

Print-Stage "STAGE 0: PACKAGE MANAGER PREFLIGHT"
if (-not (Invoke-PreflightChecks)) {
    Print-Summary
    exit 1
}

# PackageManagement in PowerShell 7 has NuGet built in and Install-PackageProvider
# fails there with a misleading "no match found" error. Only run it on 5.1.
if ($PSVersionTable.PSEdition -eq 'Desktop') {
    Invoke-OptionalStep "Install NuGet package provider" {
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    }
} else {
    Record-Success "NuGet package provider built in (PowerShell $($PSVersionTable.PSVersion))"
}
Invoke-OptionalStep "Trust PSGallery repository" {
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
}

Print-Stage "STAGE 1: WINDOWS ENVIRONMENT PROVISIONING"

# PowerShell 7 is installed from the official MSI rather than winget. winget
# correlates the Store (MSIX) build with the MSI build under the same package
# id, so if the Store build is present it reports "already installed" and
# no-ops, and after removing the Store build it can report success while
# installing nothing. The MSI is the only reliable path to Program Files.
if (Test-Pwsh7Installed) {
    Record-Success "PowerShell 7 already installed"
} else {
    Write-Log "Downloading and installing PowerShell $PwshVersion via MSI..."
    Invoke-OptionalStep "Install PowerShell 7" {
        $pwshUrl = "https://github.com/PowerShell/PowerShell/releases/download/v$PwshVersion/PowerShell-$PwshVersion-win-x64.msi"
        $pwshMsiPath = "$env:TEMP\PowerShell-$PwshVersion-win-x64.msi"
        (New-Object System.Net.WebClient).DownloadFile($pwshUrl, $pwshMsiPath)
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$pwshMsiPath`" /qn /norestart" -Wait
        Remove-Item -Path $pwshMsiPath -Force
        if (-not (Test-Pwsh7Installed)) {
            throw "MSI reported completion but $(Get-Pwsh7Path) is missing"
        }
    }
}

Invoke-WingetInstall "Windows Terminal" "Microsoft.WindowsTerminal"
Invoke-WingetInstall "Everything" "voidtools.Everything"

# PowerToys is installed via winget. Upstream stopped publishing .msi installers
# (0.100.x ships only PowerToysSetup-*.exe / PowerToysUserSetup-*.exe), so the
# old pinned-MSI download returned 404 on every run.
if (Test-PowerToysInstalled) {
    Record-Success "PowerToys already installed"
} else {
    Invoke-WingetInstall "PowerToys" "Microsoft.PowerToys"
}

# Sysinternals is downloaded straight from Microsoft. The winget manifest pins a
# hash for a rolling zip that Microsoft rebuilds in place, so winget reliably
# fails with "Installer hash does not match; this cannot be overridden when
# running as admin".
if (Test-SysinternalsInstalled) {
    Record-Success "Sysinternals Suite already installed"
} else {
    Write-Log "Downloading Sysinternals Suite directly (winget's pinned hash does not match the rolling zip)..."
    Invoke-OptionalStep "Install Sysinternals Suite" {
        $sysUrl = "https://download.sysinternals.com/files/SysinternalsSuite.zip"
        $sysZip = "$env:TEMP\SysinternalsSuite.zip"
        (New-Object System.Net.WebClient).DownloadFile($sysUrl, $sysZip)
        if (-not (Test-Path $SysinternalsPath)) {
            New-Item -ItemType Directory -Path $SysinternalsPath -Force | Out-Null
        }
        Expand-Archive -Path $sysZip -DestinationPath $SysinternalsPath -Force
        Remove-Item -Path $sysZip -Force
        Add-MachinePathEntry -Directory $SysinternalsPath
        if (-not (Test-SysinternalsInstalled)) {
            throw "Extraction completed but procexp64.exe is missing from $SysinternalsPath"
        }
    }
}

Invoke-WingetInstall "Git" "Git.Git"
Invoke-WingetInstall "GitHub CLI" "GitHub.cli"
Invoke-WingetInstall "GitHub Desktop" "GitHub.GitHubDesktop"
Invoke-WingetInstall "GitHub Copilot" "GitHub.Copilot"
Invoke-WingetInstall "Python $PythonVersion" "Python.Python.$PythonVersion"
Invoke-WingetInstall "Visual Studio Code" "Microsoft.VisualStudioCode"
Invoke-WingetInstall "Node.js LTS" "OpenJS.NodeJS.LTS"
# Stage 4 verifies rg and fastfetch, so install them here rather than reporting
# them as missing every run.
Invoke-WingetInstall "ripgrep" "BurntSushi.ripgrep.MSVC"
Invoke-WingetInstall "fastfetch" "Fastfetch-cli.Fastfetch"
Invoke-WingetInstall "Slack" "SlackTechnologies.Slack"
Invoke-WingetInstall "Bitwarden" "Bitwarden.Bitwarden"
Invoke-WingetInstall "Obsidian" "Obsidian.Obsidian"
Invoke-WingetInstall "ChatGPT" "9NT1R1C2HH7J" -Source "msstore"
Invoke-WingetInstall "Claude Desktop" "Anthropic.Claude"
Invoke-WingetInstall "Zed" "ZedIndustries.Zed"

Refresh-Path

Invoke-OptionalStep "Configure git core.fscache" { git config --global core.fscache true }
Invoke-OptionalStep "Configure git core.preloadindex" { git config --global core.preloadindex true }
Invoke-OptionalStep "Configure git gc.auto" { git config --global gc.auto 256 }

if ((git config --global user.name 2>$null) -eq "Justin Benson") {
    Record-Success "git user.name already configured"
} else {
    Invoke-OptionalStep "Configure git user.name" { git config --global user.name "Justin Benson" }
}

if ((git config --global user.email 2>$null) -eq "jbenson.dev@gmail.com") {
    Record-Success "git user.email already configured"
} else {
    Invoke-OptionalStep "Configure git user.email" { git config --global user.email "jbenson.dev@gmail.com" }
}

Invoke-OptionalStep "Register Python app path" {
    # Written without the null-conditional operator (?.) so the script still
    # parses under Windows PowerShell 5.1. A parse error there aborts the whole
    # file before the preflight check can report anything useful.
    $pythonCommand = Get-Command python -ErrorAction SilentlyContinue
    $pythonPath = if ($pythonCommand) { $pythonCommand.Source } else { $null }
    if (-not $pythonPath) {
        $pythonPath = "$env:LOCALAPPDATA\Programs\Python\Python$PythonShortVersion\python.exe"
    }
    # Set-ItemProperty cannot create the key, so create it first on a clean box.
    $appPathsKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths\python.exe"
    if (-not (Test-Path $appPathsKey)) {
        New-Item -Path $appPathsKey -Force | Out-Null
    }
    Set-ItemProperty -Path $appPathsKey -Name "(Default)" -Value $pythonPath
}

Print-Stage "STAGE 2: CONTAINERIZATION & VIRTUALIZATION"
Invoke-OptionalStep "Enable WSL2" { wsl --install --no-launch }
Invoke-WingetInstall "Docker Desktop" "Docker.DockerDesktop"

Refresh-Path

# Only seed Docker's settings.json when it does not already exist. Overwriting
# it on every run discards any settings Docker Desktop or the user has written.
if (Test-Path "$env:APPDATA\Docker\settings.json") {
    Record-Success "Docker Desktop settings already present; leaving untouched"
} else {
    Invoke-OptionalStep "Pre-accept Docker Desktop license" {
        $dockerSettingsPath = "$env:APPDATA\Docker\settings.json"
        if (!(Test-Path (Split-Path $dockerSettingsPath))) {
            New-Item -ItemType Directory -Path (Split-Path $dockerSettingsPath) -Force | Out-Null
        }
        '{"wslEngineEnabled":true,"displayedTutorial":true,"acceptLicense":true}' | Out-File -FilePath $dockerSettingsPath -Encoding utf8 -Force
    }
}

if (Get-Process -Name "Docker Desktop" -ErrorAction SilentlyContinue) {
    Record-Success "Docker Desktop already running"
} else {
    Invoke-OptionalStep "Start Docker Desktop daemon" {
        $dockerExe = "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe"
        if (Test-Path $dockerExe) {
            Start-Process $dockerExe -WindowStyle Hidden
        } else {
            throw "Docker Desktop executable not found at: $dockerExe"
        }
    }
}

Print-Stage "STAGE 3: WINDOWS AI CLI TOOLS"
Install-NpmCliIfMissing "Claude Code" "claude" "@anthropic-ai/claude-code" { npm install -g @anthropic-ai/claude-code }
Install-NpmCliIfMissing "Codex CLI" "codex" "@openai/codex" { npm install -g @openai/codex }
Invoke-WingetInstall "Google Antigravity" "Google.Antigravity"
if (Test-CommandExists "agy") {
    Record-Success "Google Antigravity CLI already installed"
} else {
    Invoke-OptionalStep "Install Google Antigravity CLI" {
        $script = Invoke-RestMethod -Uri "https://antigravity.google/cli/install.ps1"
        if ([string]::IsNullOrWhiteSpace($script)) {
            throw "Downloaded install script is empty; aborting execution"
        }
        Invoke-Expression $script
    }
    Refresh-Path
}
Install-NpmCliIfMissing "GitHub Copilot CLI" "copilot" "@github/copilot" { npm install -g @github/copilot }

Print-Stage "STAGE 4: WINDOWS STACK VERIFICATION"
Write-Log "--- CORE TOOLS ---"
Invoke-OptionalStep "Check git version" { git --version }
Invoke-OptionalStep "Check gh version" { gh --version }
Invoke-OptionalStep "Check python version" { python --version }
Invoke-OptionalStep "Check node version" { node --version }
Invoke-OptionalStep "Check npm version" { npm --version }
Invoke-OptionalStep "Check ripgrep version" { rg --version }
Invoke-OptionalStep "Check fastfetch version" { fastfetch --version }
Invoke-OptionalStep "Check PowerShell 7 version" { & (Get-Pwsh7Path) -NoProfile -Command '$PSVersionTable.PSVersion.ToString()' }
Write-Log ""
Write-Log "--- NPM GLOBALS ---"
Invoke-OptionalStep "List global npm packages" { npm list -g --depth=0 }
Write-Log "--- AI TOOLS ---"
Invoke-OptionalStep "Check Claude Code version" { claude --version }
Invoke-OptionalStep "Check Codex CLI version" { codex --version }
Invoke-OptionalStep "Check GitHub Copilot CLI version" { copilot --version }
Invoke-OptionalStep "Check Google Antigravity CLI version" { agy --version }
Write-Log "------------------------------------------------"
Write-Log "Windows bootstrap stage complete."

if ($SkipWsl) {
    Print-Stage "STAGE 5: SKIPPED (-SkipWsl)"
    Record-Success "Skipped WSL provisioner generation and RunOnce registration"
} else {
    Print-Stage "STAGE 5: GENERATE POST-REBOOT WSL PROVISIONER & SCHEDULER"

    $WslScriptContent = @'
# ==============================================================================
# WSL2 UBUNTU BOOTSTRAP (STAGE 2 - POST-REBOOT)
# ==============================================================================
Set-ExecutionPolicy RemoteSigned -Scope Process -Force

$WslLog = "$env:USERPROFILE\bootstrap_wsl_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$WslWarnings = [System.Collections.Generic.List[string]]::new()
$WslSuccesses = [System.Collections.Generic.List[string]]::new()

function Write-WslLog {
    param([string]$Message)
    Write-Host $Message
    Add-Content -Path $WslLog -Value $Message -ErrorAction SilentlyContinue
}

function Record-WslSuccess {
    param([string]$Description)
    $WslSuccesses.Add($Description)
    Write-WslLog "OK: $Description"
}

function Add-WslWarning {
    param([string]$Message)
    $WslWarnings.Add($Message)
    Write-WslLog "WARN: $Message"
}

function Invoke-WslOptionalStep {
    param([string]$Description, [scriptblock]$ScriptBlock)
    try {
        $output = & $ScriptBlock 2>&1
        if ($null -ne $output) {
            Add-Content -Path $WslLog -Value ($output | Out-String).TrimEnd() -ErrorAction SilentlyContinue
        }
        if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
            Add-WslWarning "$Description exited with code $LASTEXITCODE; continuing"
        } else {
            Record-WslSuccess $Description
        }
    } catch {
        Add-WslWarning "$Description failed; continuing: $($_.Exception.Message)"
    }
}

function Print-WslSummary {
    Write-WslLog ""
    $line = "=" * 78
    Write-WslLog $line
    Write-WslLog " WSL BOOTSTRAP FINAL SUMMARY"
    Write-WslLog $line
    Write-WslLog "Log file: $WslLog"
    Write-WslLog "Host PowerShell: $($PSVersionTable.PSVersion)"
    Write-WslLog "Successful steps: $($WslSuccesses.Count)"
    Write-WslLog "Warnings: $($WslWarnings.Count)"
    Write-WslLog ""
    Write-WslLog "Successful items:"
    foreach ($item in $WslSuccesses) { Write-WslLog "  - $item" }
    if ($WslWarnings.Count -gt 0) {
        Write-WslLog ""
        Write-WslLog "Warnings encountered:"
        foreach ($item in $WslWarnings) { Write-WslLog "  - $item" }
        Write-WslLog ""
        Write-WslLog "Review the full log at: $WslLog"
    } else {
        Write-WslLog ""
        Write-WslLog "No warnings encountered."
    }
}

Write-WslLog ("=" * 78)
Write-WslLog " WSL2 UBUNTU AI DEV BOOTSTRAP"
Write-WslLog " Log file: $WslLog"
Write-WslLog ("=" * 78)

Invoke-WslOptionalStep "Install WSL2 Ubuntu distribution" {
    wsl --install --distribution Ubuntu --no-launch
    Start-Sleep -Seconds 10
}

Invoke-WslOptionalStep "Update Linux packages" {
    wsl -u root -e bash -c "apt-get update && apt-get install -y curl git build-essential python3 python3-pip ripgrep p7zip-full"
}

Invoke-WslOptionalStep "Install Node.js LTS in WSL" {
    wsl -u root -e bash -c "curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -"
    wsl -u root -e bash -c "apt-get install -y nodejs"
}

Invoke-WslOptionalStep "Configure shared Git credentials in WSL" {
    wsl -e bash -c "git config --global credential.helper '/mnt/c/Program\ Files/Git/mingw64/bin/git-credential-manager.exe'"
}

Invoke-WslOptionalStep "Install AI CLI tools in WSL" {
    wsl -u root -e bash -c "npm install -g @anthropic-ai/claude-code @openai/codex"
}

Write-WslLog ""
Write-WslLog "--- VERIFYING WSL STACK ---"
Invoke-WslOptionalStep "Check WSL Ubuntu release" { wsl -e lsb_release -a }
Invoke-WslOptionalStep "Check WSL git version" { wsl -e git --version }
Invoke-WslOptionalStep "Check WSL node version" { wsl -e node --version }
Invoke-WslOptionalStep "Check WSL python version" { wsl -e python3 --version }
Invoke-WslOptionalStep "List WSL global npm packages" { wsl -e npm list -g --depth=0 }
Write-WslLog "----------------------------"
Write-WslLog "WSL bootstrap complete."

Print-WslSummary

Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce" -Name "WSLBootstrap" -ErrorAction SilentlyContinue
Write-Host "WSL Ubuntu Environment configuration complete! Press any key to exit."
Pause
'@

    $WslScriptReady = Invoke-RequiredStep "Generate WSL bootstrap script: $WslScriptPath" {
        $wslScriptParent = Split-Path -Parent $WslScriptPath
        if (-not (Test-Path $wslScriptParent)) {
            New-Item -ItemType Directory -Path $wslScriptParent -Force | Out-Null
        }
        $WslScriptContent | Out-File -FilePath $WslScriptPath -Encoding utf8 -Force
    }

    if ($WslScriptReady) {
        # Run the post-reboot stage under PowerShell 7 when it is present, falling
        # back to Windows PowerShell so the stage still runs if the MSI step failed.
        $RunOnceShell = if (Test-Pwsh7Installed) { Get-Pwsh7Path } else { "powershell.exe" }
        $currentRunOnce = (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce" -ErrorAction SilentlyContinue).WSLBootstrap
        $desiredRunOnce = "`"$RunOnceShell`" -ExecutionPolicy Bypass -NoExit -File `"$WslScriptPath`""
        if ($currentRunOnce -eq $desiredRunOnce) {
            Record-Success "WSL bootstrap RunOnce already configured"
        } else {
            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce" -Name "WSLBootstrap" -Value $desiredRunOnce
            Record-Success "Registered WSL bootstrap in RunOnce ($RunOnceShell)"
        }
        $WslStageRegistered = $true
    } else {
        Add-Warning "Skipping RunOnce registration because the WSL bootstrap script was not written"
    }
}

Remove-OldLogs -Filter "bootstrap_windows_*.log" -Keep $KeepLogs
Remove-OldLogs -Filter "bootstrap_wsl_*.log" -Keep $KeepLogs

Print-Summary

if ($FatalError) {
    exit 1
}

Write-Log ""
if ($NoReboot) {
    Write-Log "Windows stage complete. -NoReboot specified; skipping reboot."
    if ($WslStageRegistered) {
        Write-Log "NOTE: the WSL bootstrap is registered in RunOnce and will run at your next sign-in."
        Write-Log "      Re-run with -SkipWsl if you do not want that scheduled."
    }
    exit 0
}

Write-Log "Windows stage complete. Rebooting VM in 5 seconds to initialize WSL2..."
Start-Sleep -Seconds 5
Restart-Computer -Force
