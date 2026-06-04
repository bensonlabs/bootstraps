# Base system

winget install --id Microsoft.PowerShell -e
winget install --id Microsoft.WindowsTerminal -e
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
winget install --id Anthropic.Claude -e

# Sysinternals

winget install --id Microsoft.Sysinternals -e

# WSL2

winget install Microsoft.WSL

# AI CLI Tools

winget install Anthropic.ClaudeCode
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
