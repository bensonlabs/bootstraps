
```powershell
# ==============================================================================
# UNATTENDED DEVELOPMENT ENVIRONMENT SETUP SCRIPT
# ==============================================================================

# 1. Elevate Execution Policy for the life of this process
Set-ExecutionPolicy RemoteSigned -Scope Process -Force

# 2. Configure PowerShell Package Management (Bypasses all NuGet/PSGallery prompts)
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

# ==============================================================================
# BASE SYSTEM & UTILITIES
# ==============================================================================

# Install Modern PowerShell (Bypasses the 'Y' license agreement)
winget install --id Microsoft.PowerShell -e --accept-package-agreements --accept-source-agreements

# Install Windows Terminal & Utilities
winget install --id Microsoft.WindowsTerminal -e --accept-package-agreements --accept-source-agreements
winget install --id Microsoft.PowerToys -e --accept-package-agreements --accept-source-agreements
winget install --id voidtools.Everything -e --accept-package-agreements --accept-source-agreements

# Sysinternals Suite
winget install --id Microsoft.Sysinternals.Suite -e --accept-package-agreements --accept-source-agreements

# ==============================================================================
# GIT, CORE LANGUAGES & IDEs
# ==============================================================================

winget install --id Git.Git -e --accept-package-agreements --accept-source-agreements
winget install --id GitHub.cli -e --accept-package-agreements --accept-source-agreements
winget install --id GitHub.GitHubDesktop -e --accept-package-agreements --accept-source-agreements
winget install --id GitHub.Copilot -e --accept-package-agreements --accept-source-agreements
winget install --id Python.Python.3.13 -e --accept-package-agreements --accept-source-agreements
winget install --id Microsoft.VisualStudioCode -e --accept-package-agreements --accept-source-agreements

# Install Node.js LTS (Required for your JS-based CLI tools)
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
# CONTAINERIZATION & VIRTUALIZATION
# ==============================================================================

# WSL2 Core & Default Distro (Silent background install, no popup window)
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
# SCRIPT TOOLS & POWERSHELL MODULES
# ==============================================================================

# Installs completely silently now due to the NuGet/PSGallery pre-steps
Install-Module -Name PSScriptAnalyzer -Force -SkipPublisherCheck -Scope AllUsers

# ==============================================================================
# AI DESKTOP APPLICATIONS
# ==============================================================================

# Official Anthropic Claude Desktop app
winget install --id Anthropic.Claude -e --accept-package-agreements --accept-source-agreements

# Official OpenAI ChatGPT app (Bypasses MS Store UI interactions)
winget install --id 9NT1R1C2HH7J --source msstore -e --accept-package-agreements --accept-source-agreements

# ==============================================================================
# AI CLI TOOLS (NPM Global Installs)
# ==============================================================================

# Claude Code Agent
npm install -g @anthropic-ai/claude-code

# OpenAI Codex CLI
npm install -g @openai/codex

# Google Gemini CLI
npm install -g @google/gemini-cli

# Git-to-LLM Prompt Context Creator
npm install -g one-file-context

# FINAL PATH REFRESH: Captures globally installed npm binaries
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# ==============================================================================
# VERIFICATION (Safe, non-interactive validation checks)
# ==============================================================================
Write-Host "`n--- VERIFYING STACK ---" -ForegroundColor Cyan
& git --version
& gh --version
& python --version
& node --version
& docker --version
& npm list -g @anthropic-ai/claude-code --depth=0
& npm list -g @openai/codex --depth=0
& gemini -v
& npm list -g one-file-context --depth=0
Write-Host "------------------------" -ForegroundColor Cyan
```
