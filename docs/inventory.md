# Inventory

The inventory process captures the current state of a workstation.

## Windows Inventory

Script:

inventory-windows.ps1

Exports:

- winget-export.json
- git-config.txt
- vscode-extensions.txt
- python-packages.txt
- npm-global-packages.txt

## WSL Inventory

Script:

inventory-wsl.sh

Exports:

- apt package inventory
- shell configuration
- Python package inventory
- npm package inventory

## Purpose

Inventory data provides a snapshot of the workstation and serves as the basis for future bootstrap automation.
