# ==============================================================================
# MASTER UNATTENDED AI DEVELOPMENT ENVIRONMENT BOOTSTRAP SCRIPT
# ==============================================================================

# 1. Elevate Execution Policy for the life of this process
Set-ExecutionPolicy RemoteSigned -Scope Process -Force

# 2. Force modern TLS 1.2 encryption so Windows can talk to download servers
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# 3. Network Connection Gateway: Wait for Hyper-V Virtual Switch to assign an IP
Write-Host "Checking internet connection..." -ForegroundColor Cyan
while (!(Test-Connection -ComputerName 8.8.8.8 -Count 1 -ErrorAction SilentlyContinue)) {
    Write-Host "Waiting for network connectivity..." -ForegroundColor Yellow
    Start-Sleep -Seconds 3
}
Write-Host "Internet connection verified! Proceeding with setup." -ForegroundColor Green

# 4. Configure PowerShell Package Management (Bypasses all NuGet/PSGallery prompts)
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

# ==============================================================================
# STAGE 1: WINDOWS ENVIRONMENT PROVISIONING
# ==============================================================================

# Install Modern PowerShell (Bypasses the 'Y' license agreement)
winget install --id Microsoft.PowerShell -e --accept-package-agreements --accept-source-agreements

# Install Windows Terminal & Utilities
winget install --id Microsoft.WindowsTerminal -e --accept-package-agreements --accept-source-agreements
# Installs PowerToys silently and completely blocks the first-run welcome splash screen
winget install --id Microsoft.PowerToys -e --accept-package-agreements --accept-source-agreements --override "--silent --no_start_menu_shortcut --no_welcome" 
winget install --id voidtools.Everything -e --accept-package-agreements --accept-source-agreements

# Sysinternals Suite
winget install --id Microsoft.Sysinternals.Suite -e --accept-package-agreements --accept-source-agreements

# Git, GitHub CLI, and Copilot Extensions
winget install --id Git.Git -e --accept-package-agreements --accept-source-agreements
winget install --id GitHub.cli -e --accept-package-agreements --accept-source-agreements
winget install --id GitHub.GitHubDesktop -e --accept-package-agreements --accept-source-agreements
winget install --id GitHub.Copilot -e --accept-package-agreements --accept-source-agreements

# Runtimes & IDEs
winget install --id Python.Python.3.13 -e --accept-package-agreements --accept-source-agreements
winget install --id Microsoft.VisualStudioCode -e --accept-package-agreements --accept-source-agreements
winget install --id OpenJS.NodeJS.LTS -e --accept-package-agreements --accept-source-agreements

# FIRST PATH REFRESH: Ensures 'npm', 'git', and Sysinternals work immediately
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Git Performance Optimization Overrides
git config --global core.fscache true
git config --global core.preloadindex true
git config --global gc.auto 256

# Explicit Windows App Path registration for global Python use
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths\python.exe" -Name "(Default)" -Value "C:\Program Files\Python313\python.exe" -ErrorAction SilentlyContinue

# ==============================================================================
# CONTAINERIZATION & VIRTUALIZATION (WINDOWS CORE)
# ==============================================================================

# Enable underlying WSL2 Windows Features natively
wsl --install --no-launch

# Docker Desktop
winget install --id Docker.DockerDesktop -e --accept-package-agreements --accept-source-agreements

# SECOND PATH REFRESH: Captures the new Docker binaries path
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Pre-accept Docker Desktop license agreements silently in the configuration structure
$dockerSettingsPath = "$env:APPDATA\Docker\settings.json"
if (!(Test-Path (Split-Path $dockerSettingsPath))) { New-Item -ItemType Directory -Path (Split-Path $dockerSettingsPath) -Force | Out-Null }
'{"wslEngineEnabled":true,"displayedTutorial":true,"acceptLicense":true}' | Out-File -FilePath $dockerSettingsPath -Encoding utf8 -Force

# Initialize the background Docker Daemon silently so verification doesn't stall
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe" -WindowStyle Hidden

# ==============================================================================
# POWERSHELL MODULES & WINDOWS AI APPLICATIONS
# ==============================================================================

# Script Analysis Module
Install-Module -Name PSScriptAnalyzer -Force -SkipPublisherCheck -Scope AllUsers

# Official Anthropic Claude Desktop app
winget install --id Anthropic.Claude -e --accept-package-agreements --accept-source-agreements

# Official OpenAI ChatGPT app (Bypasses MS Store UI interactions)
winget install --id 9NT1R1C2HH7J --source msstore -e --accept-package-agreements --accept-source-agreements

# ==============================================================================
# WINDOWS AI CLI TOOLS (NPM Global Installs)
# ==============================================================================

npm install -g @anthropic-ai/claude-code
npm install -g @openai/codex
npm install -g @google/gemini-cli
npm install -g one-file-context

# THIRD PATH REFRESH: Captures globally installed Windows npm binaries
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# ==============================================================================
# WINDOWS STACK VERIFICATION 
# ==============================================================================
Write-Host "`n--- VERIFYING WINDOWS STACK ---" -ForegroundColor Cyan
& git --version
& gh --version
& python --version
& node --version
& docker --version
& npm list -g @anthropic-ai/claude-code --depth=0
& npm list -g @openai/codex --depth=0
& gemini -v
& npm list -g one-file-context --depth=0
Write-Host "-------------------------------" -ForegroundColor Cyan

# ==============================================================================
# STAGE 2: GENERATE POST-REBOOT WSL PROVISIONER & SCHEDULER
# ==============================================================================

$wslScriptPath = "$env:USERPROFILE\Desktop\wsl_bootstrap.ps1"

@'
# Elevate execution for stage 2
Set-ExecutionPolicy RemoteSigned -Scope Process -Force

Write-Host "Initializing Ubuntu Environment..." -ForegroundColor Cyan

# Force WSL to download and register the absolute latest Ubuntu image available
wsl --install --distribution Ubuntu --no-launch

# Brief pause to allow the subsystem registration to finalize in memory
Start-Sleep -Seconds 10

Write-Host "Configuring matching stack inside WSL2 (Ubuntu Latest)..." -ForegroundColor Cyan

# 1. Update Linux packages
wsl -u root -e bash -c "apt-get update && apt-get install -y curl git build-essential"

# 2. Install Node.js LTS natively inside Linux
wsl -u root -e bash -c "curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -"
wsl -u root -e bash -c "apt-get install -y nodejs"

# 3. Share Windows Git credentials with Linux
wsl -e bash -c "git config --global credential.helper '/mnt/c/Program\ Files/Git/mingw64/bin/git-credential-manager.exe'"

# 4. Install matching AI CLI Tools globally inside Linux
wsl -u root -e bash -c "npm install -g @anthropic-ai/claude-code @openai/codex @google/gemini-cli one-file-context"

# 5. WSL Verification Output
Write-Host "`n--- VERIFYING WSL STACK ---" -ForegroundColor Cyan
wsl -e lsb_release -a
wsl -e git --version
wsl -e node --version
wsl -e npm list -g --depth=0
Write-Host "------------------------" -ForegroundColor Cyan

# Self-destruct this temporary script runner when finished
Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce" -Name "WSLBootstrap" -ErrorAction SilentlyContinue
Write-Host "WSL Ubuntu Environment configuration complete! Press any key to exit."
Pause
'@ | Out-File -FilePath $wslScriptPath -Encoding utf8 -Force

# Register the script to run automatically with explicit Bypass privileges on next login
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce" -Name "WSLBootstrap" -Value "powershell.exe -ExecutionPolicy Bypass -NoExit -File `"$wslScriptPath`""

# Force the VM restart right now to complete WSL/Docker feature installations
Write-Host "Windows stage complete. Rebooting VM in 5 seconds to initialize WSL2..." -ForegroundColor Yellow
Start-Sleep -Seconds 5
Restart-Computer -Force
