```powershell
# Scratch notes of things I've learned

# Base system
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
winget install --id Microsoft.PowerShell -e
  - had to accept with Y
winget install --id Microsoft.WindowsTerminal -e
  - had to restart terminal
winget install --id Microsoft.PowerToys -e
winget install --id voidtools.Everything -e

# Git and GitHub

winget install --id Git.Git -e
winget install --id GitHub.cli -e
winget install --id GitHub.GitHubDesktop -e

# Languages

winget install --id Python.Python.3.13 -e
winget install --id OpenJS.NodeJS.LTS -e

# Visual Studio Code

winget install --id Microsoft.VisualStudioCode -e

# Docker

winget install --id Docker.DockerDesktop -e

# AI Desktop apps

winget install --id OpenAI.ChatGPT -e
  - No package found matching input criteria.
  - failed/tried: winget.exe install --id=9NT1R1C2HH7J --source=msstore --accept-package-agreements --accept-source-agreements –silent
    - https://help.openai.com/en/articles/10003026-windows-app-release-notes
    - went with (legit?) winget install -e --id lencx.ChatGPT 
winget install --id Anthropic.Claude -e

# Sysinternals

winget install --id=Microsoft.Sysinternals.Suite -e
  - Path environment variable modified; restart your shell to use the new value.
    - ran after it: $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Script tools
winget install --id Microsoft.PowerShell.PSScriptAnalyzer --source winget
  - ran this: Install-Module -Name PSScriptAnalyzer -Force -SkipPublisherCheck -Scope AllUsers
    - needs to press y
# WSL2

no: winget install Microsoft.WSL
yes: wsl --install --no-launch

# AI CLI Tools

#winget install Anthropic.ClaudeCode
winget install --id=Anthropic.ClaudeCode -e
winget install --id=OpenAI.Codex -e
npm install -g @openai/codex
npm install -g @google/gemini-cli

# Verification
git --version
gh --version
python --version
node --version
docker --version
claude --version
codex --version
gemini --version
```
