# ==============================================================================
# UNATTENDED AI DEVELOPMENT ENVIRONMENT BOOTSTRAP - WINDOWS 11
# ==============================================================================

# 1. Elevate Execution Policy for the life of this process
Set-ExecutionPolicy RemoteSigned -Scope Process -Force

# 2. Force modern TLS 1.2 encryption so Windows can talk to download servers
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$BootstrapLog = "$env:USERPROFILE\bootstrap_windows_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$Warnings = [System.Collections.Generic.List[string]]::new()
$Successes = [System.Collections.Generic.List[string]]::new()
$OsVersion = (Get-CimInstance Win32_OperatingSystem).Caption
$PowerToysVersion = "0.99.1"
$PythonVersion = "3.13"
$PythonShortVersion = $PythonVersion -replace "\.", ""

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

function Print-Stage {
    param([string]$Title)
    $line = "=" * 78
    Write-Log $line
    Write-Log " $Title"
    Write-Log $line
}

function Invoke-OptionalStep {
    param([string]$Description, [scriptblock]$ScriptBlock)
    try {
        $output = & $ScriptBlock 2>&1
        Add-Content -Path $BootstrapLog -Value ($output | Out-String).TrimEnd() -ErrorAction SilentlyContinue
        if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
            Add-Warning "$Description exited with code $LASTEXITCODE; continuing"
        } else {
            Record-Success $Description
        }
    } catch {
        Add-Warning "$Description failed; continuing: $($_.Exception.Message)"
    }
}

function Invoke-WingetInstall {
    param(
        [string]$Description,
        [string]$Id,
        [string]$Source = "winget"
    )
    $wingetArgs = @("install", "--id", $Id, "-e", "--accept-package-agreements", "--accept-source-agreements")
    if ($Source -ne "winget") {
        $wingetArgs += @("--source", $Source)
    }
    try {
        $output = & winget @wingetArgs 2>&1
        Add-Content -Path $BootstrapLog -Value ($output | Out-String).TrimEnd() -ErrorAction SilentlyContinue
        # 0 = success; -1978335189 = already installed (treat as success)
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

function Print-Summary {
    Write-Log ""
    $line = "=" * 78
    Write-Log $line
    Write-Log " FINAL SUMMARY"
    Write-Log $line
    Write-Log "Log file: $BootstrapLog"
    Write-Log "OS: $OsVersion"
    Write-Log "Successful steps: $($Successes.Count)"
    Write-Log "Warnings: $($Warnings.Count)"
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
Write-Log ("=" * 78)

# 3. Network Connection Gateway: Wait for Hyper-V Virtual Switch to assign an IP
Write-Log "Checking internet connection..."
while (!(Test-Connection -ComputerName 8.8.8.8 -Count 1 -ErrorAction SilentlyContinue)) {
    Write-Log "Waiting for network connectivity..."
    Start-Sleep -Seconds 3
}
Record-Success "Internet connection verified"

# 4. Configure PowerShell Package Management (bypasses all NuGet/PSGallery prompts)
Invoke-OptionalStep "Install NuGet package provider" {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
}
Invoke-OptionalStep "Trust PSGallery repository" {
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
}

# ==============================================================================
Print-Stage "STAGE 1: WINDOWS ENVIRONMENT PROVISIONING"
# ==============================================================================

Invoke-WingetInstall "Modern PowerShell" "Microsoft.PowerShell"
Invoke-WingetInstall "Windows Terminal" "Microsoft.WindowsTerminal"
Invoke-WingetInstall "Everything" "voidtools.Everything"

# SILENT POWERTOYS MSI INSTALLATION (bypasses WiX Bootstrapper & pop-up engines)
Write-Log "Downloading and installing PowerToys via MSI..."
Invoke-OptionalStep "Install PowerToys" {
    $ptUrl = "https://github.com/microsoft/PowerToys/releases/download/v$PowerToysVersion/PowerToysSetup-$PowerToysVersion-x64.msi"
    $ptPath = "$env:TEMP\PowerToysSetup.msi"
    (New-Object System.Net.WebClient).DownloadFile($ptUrl, $ptPath)
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$ptPath`" /qn /norestart" -Wait
    Remove-Item -Path $ptPath -Force
}

Invoke-WingetInstall "Sysinternals Suite" "Microsoft.Sysinternals.Suite"
Invoke-WingetInstall "Git" "Git.Git"
Invoke-WingetInstall "GitHub CLI" "GitHub.cli"
Invoke-WingetInstall "GitHub Desktop" "GitHub.GitHubDesktop"
Invoke-WingetInstall "GitHub Copilot" "GitHub.Copilot"
Invoke-WingetInstall "Python $PythonVersion" "Python.Python.$PythonVersion"
Invoke-WingetInstall "Visual Studio Code" "Microsoft.VisualStudioCode"
Invoke-WingetInstall "Node.js LTS" "OpenJS.NodeJS.LTS"
Invoke-WingetInstall "Slack" "SlackTechnologies.SlackS"

Refresh-Path

Invoke-OptionalStep "Configure git core.fscache" { git config --global core.fscache true }
Invoke-OptionalStep "Configure git core.preloadindex" { git config --global core.preloadindex true }
Invoke-OptionalStep "Configure git gc.auto" { git config --global gc.auto 256 }
Invoke-OptionalStep "Configure git user.name" { git config --global user.name "Justin Benson" }
Invoke-OptionalStep "Configure git user.email" { git config --global user.email "jbenson.dev@gmail.com" }

Invoke-OptionalStep "Register Python app path" {
    $pythonPath = (Get-Command python -ErrorAction SilentlyContinue)?.Source
    if (-not $pythonPath) {
        # Fall back to the conventional install location for the configured version
        $pythonPath = "$env:ProgramFiles\Python$PythonShortVersion\python.exe"
    }
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths\python.exe" -Name "(Default)" -Value $pythonPath
}

# ==============================================================================
Print-Stage "STAGE 2: CONTAINERIZATION & VIRTUALIZATION"
# ==============================================================================

Invoke-OptionalStep "Enable WSL2" { wsl --install --no-launch }
Invoke-WingetInstall "Docker Desktop" "Docker.DockerDesktop"

Refresh-Path

Invoke-OptionalStep "Pre-accept Docker Desktop license" {
    $dockerSettingsPath = "$env:APPDATA\Docker\settings.json"
    if (!(Test-Path (Split-Path $dockerSettingsPath))) {
        New-Item -ItemType Directory -Path (Split-Path $dockerSettingsPath) -Force | Out-Null
    }
    '{"wslEngineEnabled":true,"displayedTutorial":true,"acceptLicense":true}' | Out-File -FilePath $dockerSettingsPath -Encoding utf8 -Force
}

Invoke-OptionalStep "Start Docker Desktop daemon" {
    $dockerExe = "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe"
    if (Test-Path $dockerExe) {
        Start-Process $dockerExe -WindowStyle Hidden
    } else {
        throw "Docker Desktop executable not found at: $dockerExe"
    }
}

# ==============================================================================
Print-Stage "STAGE 3: POWERSHELL MODULES & WINDOWS AI APPLICATIONS"
# ==============================================================================

Invoke-OptionalStep "Install PSScriptAnalyzer" {
    Install-Module -Name PSScriptAnalyzer -Force -SkipPublisherCheck -Scope AllUsers
}

Invoke-WingetInstall "Claude Desktop" "Anthropic.Claude"
# Official OpenAI ChatGPT app (bypasses MS Store UI interactions)
Invoke-WingetInstall "ChatGPT" "9NT1R1C2HH7J" -Source "msstore"

# ==============================================================================
Print-Stage "STAGE 4: WINDOWS AI CLI TOOLS"
# ==============================================================================

Invoke-OptionalStep "Install Claude Code" { npm install -g @anthropic-ai/claude-code }
Invoke-OptionalStep "Install Codex CLI" { npm install -g @openai/codex }
Invoke-WingetInstall "Google Antigravity" "Google.Antigravity"
# Note: Invoke-RestMethod + Invoke-Expression is the vendor-documented install method for this CLI.
# Verify the URL is trusted before running on a machine with sensitive data.
Invoke-OptionalStep "Install Google Antigravity CLI" {
    $script = Invoke-RestMethod -Uri "https://antigravity.google/cli/install.ps1"
    if ([string]::IsNullOrWhiteSpace($script)) {
        throw "Downloaded install script is empty; aborting execution"
    }
    Invoke-Expression $script
}
Invoke-OptionalStep "Install one-file-context" { npm install -g one-file-context }

Refresh-Path

# ==============================================================================
Print-Stage "STAGE 5: WINDOWS STACK VERIFICATION"
# ==============================================================================

Write-Log "--- CORE TOOLS ---"
Invoke-OptionalStep "Check git version" { git --version }
Invoke-OptionalStep "Check gh version" { gh --version }
Invoke-OptionalStep "Check python version" { python --version }
Invoke-OptionalStep "Check node version" { node --version }
Invoke-OptionalStep "Check docker version" { docker --version }
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

Print-Summary

# ==============================================================================
Print-Stage "STAGE 6: GENERATE POST-REBOOT WSL PROVISIONER & SCHEDULER"
# ==============================================================================

$wslScriptPath = "$env:USERPROFILE\Desktop\wsl_bootstrap.ps1"

@'
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
        Add-Content -Path $WslLog -Value ($output | Out-String).TrimEnd() -ErrorAction SilentlyContinue
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
    wsl -u root -e bash -c "apt-get update && apt-get install -y curl git build-essential"
}

Invoke-WslOptionalStep "Install Node.js LTS in WSL" {
    wsl -u root -e bash -c "curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -"
    wsl -u root -e bash -c "apt-get install -y nodejs"
}

Invoke-WslOptionalStep "Configure shared Git credentials in WSL" {
    wsl -e bash -c "git config --global credential.helper '/mnt/c/Program\ Files/Git/mingw64/bin/git-credential-manager.exe'"
}

Invoke-WslOptionalStep "Install AI CLI tools in WSL" {
    wsl -u root -e bash -c "npm install -g @anthropic-ai/claude-code @openai/codex google-antigravity-cli one-file-context"
}

Write-WslLog ""
Write-WslLog "--- VERIFYING WSL STACK ---"
Invoke-WslOptionalStep "Check WSL Ubuntu release" { wsl -e lsb_release -a }
Invoke-WslOptionalStep "Check WSL git version" { wsl -e git --version }
Invoke-WslOptionalStep "Check WSL node version" { wsl -e node --version }
Invoke-WslOptionalStep "List WSL global npm packages" { wsl -e npm list -g --depth=0 }
Write-WslLog "----------------------------"
Write-WslLog "WSL bootstrap complete."

Print-WslSummary

Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce" -Name "WSLBootstrap" -ErrorAction SilentlyContinue
Write-Host "WSL Ubuntu Environment configuration complete! Press any key to exit."
Pause
'@ | Out-File -FilePath $wslScriptPath -Encoding utf8 -Force

Record-Success "Generated WSL bootstrap script: $wslScriptPath"

# Register the script to run automatically with explicit Bypass privileges on next login
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce" -Name "WSLBootstrap" -Value "powershell.exe -ExecutionPolicy Bypass -NoExit -File `"$wslScriptPath`""
Record-Success "Registered WSL bootstrap in RunOnce"

Write-Log ""
Write-Log "Windows stage complete. Rebooting VM in 5 seconds to initialize WSL2..."
Start-Sleep -Seconds 5
Restart-Computer -Force
