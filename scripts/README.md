# Scripts

This directory contains operational scripts used to inventory, export, validate, and bootstrap supported environments.

These scripts are intended to automate repetitive tasks and reduce manual configuration during workstation rebuilds.

## Design Principles

- Scripts should be reproducible.
- Scripts should be idempotent whenever practical.
- Scripts should be safe to run multiple times.
- Scripts should favor documentation and readability over cleverness.
- Scripts should produce predictable output.

## Script Categories

### Inventory

Scripts that capture the current state of a machine.

Current scripts:

* inventory-windows.ps1
* inventory-wsl.sh

Purpose:

- Capture installed software
- Capture package inventories
- Capture configuration state
- Generate export files

Output is typically written to the exports/ directory.

### Export

Scripts that export specific configuration or application data.

Current scripts:

* export-vscode.ps1
* export-winget.ps1

Purpose:

- Generate reusable configuration files
- Create machine snapshots
- Support bootstrap automation

### Bootstrap

Scripts that automate workstation setup from a clean installation.

Current scripts:

* bootstrap_windows.ps1
* bootstrap_ubuntu.sh
* bootstrap_macOS.sh
* bootstrap_fedora.sh

Purpose:

- Bootstrap supported environments from a clean install
- Reduce manual workstation setup steps
- Provide repeatable automation across platforms

## Usage

Run scripts from the root of the repository unless otherwise documented.

Example:

powershell
.\scripts\inventory-windows.ps1

bash
./scripts/inventory-wsl.sh

## Expected Outputs

Inventory and export scripts should write generated data to:

- exports/

Generated files may include:

- winget exports
- package inventories
- VS Code extensions
- Git configuration
- environment information

## Development Guidelines

Before adding a new script:

1. Determine whether the task is repeatable.
2. Determine whether the task belongs in automation.
3. Document the script's purpose.
4. Test on a clean environment when possible.

Scripts should be considered part of the workstation infrastructure and maintained accordingly.

## Long-Term Goal

The long-term goal of this directory is to make workstation rebuilding predictable and repeatable.

If a workstation can be recreated from the scripts and documentation in this repository, the automation is considered successful.
