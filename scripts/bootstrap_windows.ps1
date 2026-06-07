# ==============================================================================
# MASTER UNATTENDED AI DEVELOPMENT ENVIRONMENT BOOTSTRAP SCRIPT
# Designed to be run remotely via PowerShell Admin prompt:
# Set-ExecutionPolicy Bypass -Scope Process -Force; irm https://raw.githubusercontent.com/bensonlabs/bootstraps/main/scripts/bootstrap_windows.ps1 -OutFile bootstrap_windows.ps1; .\bootstrap_windows.ps1
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

# Install Modern PowerShell & Windows Terminal (Bypasses license agreements)
winget install --id Microsoft.PowerShell -e --accept-package-agreements --accept-source-agreements
winget install --id Microsoft.WindowsTerminal -e --accept-package-agreements --accept-source-agreements

# Installs PowerToys silently (acts as your Windows 'Caffeine' alternative via Awake)
Write-Host "Downloading and installing PowerToys silently..." -ForegroundColor Cyan
$ptUrl = "https://github.com/microsoft/PowerToys/releases/download/v0.99.1/PowerToysUserSetup-0.99.1-x64.exe"
$ptPath = "$env:TEMP\PowerToysUserSetup.exe"
Invoke-WebRequest -Uri $ptUrl -OutFile $ptPath
Start-Process -FilePath $ptPath -ArgumentList "/quiet /install /norestart" -Wait
Remove-Item -Path $ptPath -Force

# Install Core System Utilities
winget install --id voidtools.Everything -e --accept-package-agreements --accept-source-agreements
winget install --id 7zip.7zip -e --accept-package-agreements --accept-source-agreements
winget install --id Microsoft.Sysinternals.Suite -e --accept-package-agreements --accept-source-agreements

# Git & GitHub Core Infrastructure Layout
winget install --id Git.Git -e --accept-package-agreements --accept-source-agreements
winget install --id GitHub.cli -e --accept-package-agreements --accept-source-agreements
winget install --id GitHub.GitHubDesktop -e --accept-package-agreements --accept-source-agreements

# Runtimes, Languages & IDEs
winget install --id Python.Python.3.13 -e --accept-package-agreements --accept-source-agreements
winget install --id Microsoft.VisualStudioCode -e --accept-package-agreements --accept-source-agreements
winget install --id OpenJS.NodeJS.LTS -e --accept-package-agreements --accept-source-agreements

# Mirrored macOS/Linux Daily Driver Tool Set
winget install --id Astral.uv -e --accept-package-agreements --accept-source-agreements
winget install --id BurntSushi.ripgrep -e --accept-package-agreements --accept-source-agreements
winget install --id sharkdp.bat -e --accept-package-agreements --accept-source-agreements
winget install --id GnuWin32.Tree -e --accept-package-agreements --accept-source-agreements
winget install --id Starship.Starship -e --accept-package-agreements --accept-source-agreements
winget install --id fish-shell.fish -e --accept-package-agreements --accept-source-agreements

# GUI Applications Mirrored from macOS layout
winget install --id Obsidian.Obsidian -e --accept-package-agreements --accept-source-agreements
winget install --id Tailscale.Tailscale -e --accept-package-agreements --accept-source-agreements

# FIRST PATH REFRESH: Ensures package managers and tools work immediately
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
npm install -g gemini-cli
npm install -g one-file-context

# THIRD PATH REFRESH: Captures globally installed Windows npm binaries
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# ==============================================================================
# GLOBAL BINARY EMULATION ('ll' for Windows Terminal / Powershell / CMD)
# ==============================================================================
Write-Host "🛠️ Creating custom 'll' system binary wrapper..." -ForegroundColor Cyan
$llScript = @"
@echo off
rem Replicates directory grouping, long file listings, and hidden entries cleanly
dir /A /N /O:G %*
"@
Out-File -FilePath "$env:SystemRoot\System32\ll.bat" -InputObject $llScript -Encoding ASCII -Force

# ==============================================================================
# WINDOWS STACK VERIFICATION 
# ==============================================================================
Write-Host "`n--- VERIFYING WINDOWS STACK ---" -ForegroundColor Cyan
& git --version
& gh --version
& python --version
& node --version
& docker --version
& uv --version
& starship --version | Select-Object -First 1
& npm list -g @anthropic-ai/claude-code --depth=0
& npm list -g @openai/codex --depth=0
& gemini --version
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

# 1. Optimize internal apt-get mirrors inside subsystem environment
wsl -u root -e bash -c "echo 'APT::Periodic::Enable \"0\";' > /etc/apt/apt.conf.d/99parallel-downloads"
wsl -u root -e bash -c "apt-get update && apt-get dist-upgrade -y"

# 2. Install matching core Linux daily driver stack natively
wsl -u root -e bash -c "apt-get install -y curl git build-essential ripgrep bat tree fish zsh"

# 3. Fix internal Ubuntu 'batcat' shortcut wrapper pathing
wsl -u root -e bash -c "if [ ! -f /usr/local/bin/bat ] && command -v batcat &> /dev/null; then ln -s /usr/bin/batcat /usr/local/bin/bat; fi"

# 4. Fetch platform-independent binaries directly into the shell layer
wsl -e bash -c "curl -sS https://starship.rs/install.sh | sh -s -- -y"
wsl -e bash -c "curl -LsSf https://astral.sh/uv/install.sh | sh"

# 5. Share host Windows Git credentials securely with Linux instance
wsl -e bash -c "git config --global credential.helper '/mnt/c/Program\ Files/Git/mingw64/bin/git-credential-manager.exe'"
wsl -e bash -c "git config --global core.fscache true"

# 6. Install matching Node.js environment
wsl -u root -e bash -c "curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -"
wsl -u root -e bash -c "apt-get install -y nodejs"

# 7. Install synchronized AI tools globally inside Linux subsystem container
wsl -u root -e bash -c "npm install -g @anthropic-ai/claude-code @openai/codex gemini-cli one-file-context"

# 8. Create custom Linux 'll' command inside the native binary subsystem route
wsl -u root -e bash -c "echo -e '#!/bin/sh\nexec ls -laF --color=auto --group-directories-first \"\$@\"' > /usr/local/bin/ll"
wsl -u root -e bash -c "chmod +x /usr/local/bin/ll"

# 9. WSL Verification Output
Write-Host "`n--- VERIFYING WSL STACK ---" -ForegroundColor Cyan
wsl -e bash -c "[ -f /etc/os-release ] && grep 'PRETTY_NAME' /etc/os-release"
wsl -e git --version
wsl -e node --version
wsl -e uv --version
wsl -e starship --version | Select-Object -First 1
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
