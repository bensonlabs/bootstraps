WSL2 Ubuntu

Ubuntu-based WSL2 development environment.

This directory contains scripts, package inventories, and configuration required to rebuild the Linux development environment used alongside Windows.

Goals

* Consistent Linux development environment
* Reproducible package installation
* AI tool compatibility
* Cross-platform workflow support

Contents

packages/

Lists of Ubuntu packages required for development and automation.

configs/

Linux-specific configuration files and shell customizations.

bootstrap.sh

Primary Ubuntu bootstrap script.

Core Components

* Ubuntu LTS
* Git
* Python
* Node.js
* Docker tooling
* Claude Code
* Codex CLI
* Gemini CLI

Relationship to Windows

Windows serves as the desktop environment.

WSL2 Ubuntu serves as the Linux execution environment.

Both environments should be capable of supporting development workflows independently.