# bootstraps

A collection of reproducible workstation, development environment, and AI tooling bootstrap configurations.

The goal of this repository is simple: any supported environment should be rebuildable from a clean installation using documented procedures, exported configuration, and automation scripts stored here.

This repository serves as the source of truth for my personal development environments across Windows, WSL, and additional platforms supported through shared bootstrap scripts.

## Objectives

* Rebuild a workstation from scratch with minimal manual configuration
* Capture environment configuration before it is forgotten
* Maintain version-controlled documentation of tools and settings
* Support AI-assisted development workflows
* Reduce configuration drift between machines
* Provide a repeatable process for testing and validating rebuilds

## Current Platforms

Windows and WSL2 Ubuntu currently have dedicated top-level directories with platform-specific configuration and documentation. Additional platform bootstrap automation currently lives in scripts/.

### Windows 11

Location: windows/

Contains:

* Winget package definitions
* PowerShell profiles
* Windows Terminal configuration
* VS Code configuration
* Bootstrap and installation scripts

### WSL2 Ubuntu

Location: wsl2-ubuntu/

Contains:

* Ubuntu bootstrap scripts
* Package inventories
* Linux-specific configuration

### macOS

Bootstrap script available: scripts/bootstrap_macOS.sh

macOS currently has bootstrap automation in scripts/ and does not yet have the same top-level configuration/documentation depth as Windows and WSL2 Ubuntu.

### Fedora Workstation KDE Plasma

Bootstrap script available: scripts/bootstrap_fedora.sh

Fedora currently has bootstrap automation in scripts/ and does not yet have the same top-level configuration/documentation depth as Windows and WSL2 Ubuntu.

## AI Tooling

Location: ai/

Supported tools:

* Claude Code
* Codex CLI
* Gemini CLI

Each tool directory contains installation notes, configuration guidance, and workflow documentation.

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