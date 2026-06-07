# bootstraps

A collection of reproducible workstation, development environment, and AI tooling bootstrap configurations.

The goal of this repository is simple: any supported environment should be rebuildable from a clean installation using documented procedures, exported configuration, and automation scripts stored here.

This repository serves as the source of truth for my personal development environments across Windows, WSL, and additional platforms supported through bootstrap scripts in scripts/.

## Objectives

* Rebuild a workstation from scratch with minimal manual configuration
* Capture environment configuration before it is forgotten
* Maintain version-controlled documentation of tools and settings
* Support AI-assisted development workflows
* Reduce configuration drift between machines
* Provide a repeatable process for testing and validating rebuilds

## Current Platforms

Windows and WSL2 Ubuntu currently have dedicated top-level directories with platform-specific configuration and documentation. Other platforms currently use script-first bootstrap automation in scripts/.

### Windows 11

Location: windows/

Contains:

* Winget package definitions
* PowerShell profiles
* Windows Terminal configuration
* VS Code configuration

Bootstrap script: `scripts/bootstrap_windows.ps1`

### WSL2 Ubuntu

Location: wsl2-ubuntu/

Contains:

* Package inventories
* Linux-specific configuration

Bootstrapped as Stage 2 of `scripts/bootstrap_windows.ps1`.

### macOS

Bootstrap script available: scripts/bootstrap_macOS.sh

Contains:

* A macOS bootstrap entry point for clean-install setup automation

### Fedora Workstation KDE Plasma

Bootstrap script available: scripts/bootstrap_fedora.sh

Contains:

* A Fedora bootstrap entry point for clean-install setup automation

## AI Tooling

Location: ai/

Supported tools:

* Claude Code
* Codex CLI
* Gemini CLI

See `ai/README.md` for documentation on each tool. Tool-specific documentation is in progress.

## Inventory and Exports

Location: exports/

This directory contains machine-generated exports and environment snapshots, including:

* Winget exports
* Python package inventories
* npm package inventories
* Git configuration exports
* VS Code extension inventories

These files provide a record of workstation state at specific points in time.

## Documentation

Location: docs/

Key documents:

| Document | Purpose |
|----------|---------|
| workstation-spec.md | Defines the target workstation configuration |
| inventory.md | Tracks installed software and environment details |
| rebuild-process.md | Documents rebuild procedures and validation steps |
| github-auth.md | GitHub authentication standards and setup |

## Rebuild Philosophy

A successful bootstrap is one that can be used to destroy and recreate an environment without relying on memory.

If a machine cannot be rebuilt from the contents of this repository, the repository is incomplete.

### Validation Process

1. Build a clean environment
2. Export configuration and inventories
3. Update documentation
4. Generate or update automation
5. Destroy the environment
6. Rebuild from repository contents
7. Document gaps
8. Repeat


## Status

This repository is under active development and serves as the foundation for a reproducible AI-assisted development workstation.