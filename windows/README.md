Windows

Windows workstation bootstrap resources.

This directory contains everything required to build and maintain a Windows 11 development workstation from a clean installation.

Goals

* Fully reproducible Windows workstation
* AI-assisted development environment
* Minimal manual configuration
* Version-controlled settings and documentation

Contents

winget/

Package definitions and application inventories used to install software through WinGet.

powershell/

PowerShell profiles, functions, aliases, and shell customizations.

terminal/

Windows Terminal configuration and preferences.

vscode/

Visual Studio Code settings, extension inventories, and editor configuration.

configs/

Miscellaneous Windows configuration files that do not fit into other categories.

Bootstrap Script

scripts/bootstrap_windows.ps1 is the primary Windows bootstrap script. It handles Windows setup and generates a Stage 2 script that runs inside WSL2 after reboot.

Target Environment

* Windows 11 Pro
* PowerShell 7
* Windows Terminal
* Git
* GitHub CLI
* VS Code
* Docker Desktop
* WSL2 Ubuntu
* Claude Code
* Codex CLI
* Gemini CLI

Validation

A successful Windows bootstrap should allow a clean Windows installation to be configured with minimal manual intervention.