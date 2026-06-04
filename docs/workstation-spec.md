# Workstation Specification

Version: 1.0

## Purpose

This document defines the target state for the primary AI-assisted development workstation.

All bootstrap scripts, inventories, exports, and automation within this repository exist to reproduce the environment described here.

If the workstation can be rebuilt from a clean installation to match this specification, the bootstrap process is considered successful.

## Host Operating System

### Primary Platform

* Windows 11 Pro
* Current release: 24H2 or later
* Local administrator access required

### Secondary Platform

* WSL2 Ubuntu LTS
* Serves as the Linux execution environment

## Workstation Philosophy

The workstation should be:

* Reproducible
* Documented
* Version controlled
* AI-first
* Platform-aware
* Disposable and rebuildable

No workstation should contain configuration that cannot be recreated from this repository.

## Core Development Tools

### Source Control

#### Tool Purpose
Git	Version control
GitHub CLI	GitHub automation and authentication
GitHub Desktop	Visual repository management

### Editor

#### Tool Purpose
Visual Studio Code	Primary editor and IDE

### Languages

####Tool Purpose
PowerShell 7	Windows automation
Python	General scripting and development
Node.js LTS	AI tooling and development ecosystem

## AI Toolchain

### Required

#### Tool Status
Claude Code	Required
Codex CLI	Required
Gemini CLI	Required

### Desktop Applications

####Tool Purpose
ChatGPT Desktop	Interactive AI assistance
Claude Desktop	AI workflows and MCP support

## Principles

* AI tools are considered core development dependencies.
* AI tooling should be available in both Windows and WSL environments where practical.
* Authentication methods should be documented and reproducible.

## Windows Components

Terminal

* Windows Terminal
* PowerShell 7 default profile

## Utilities

* PowerToys
* Everything Search
* Sysinternals Suite

## Package Management

* WinGet

## Linux Components

#### Distribution

* Ubuntu LTS under WSL2

#### Package Management

* apt

#### Core Packages

* git
* curl
* wget
* build-essential
* python3
* nodejs
* jq
* ripgrep
* fzf

### Container Platform

Docker

* Docker Desktop
* Docker CLI available in Windows
* Docker CLI available in WSL

### Authentication Standards

GitHub

#### Preferred:

* SSH keys
* GitHub CLI authentication

#### Fallback:

* Personal Access Tokens

### SSH

* One SSH key per machine
* Private keys never copied between systems
* Public keys registered in GitHub

## Configuration Management

Configuration should be stored in version control whenever possible.

Examples include:

* PowerShell profiles
* VS Code settings
* VS Code extensions
* Windows Terminal settings
* Git configuration
* Bootstrap scripts

## Validation Requirements

A successful rebuild must provide:

* Git access
* GitHub access
* VS Code functionality
* Claude Code functionality
* Codex CLI functionality
* Gemini CLI functionality
* WSL2 Ubuntu functionality
* Docker functionality

## Future Platforms

Planned support:

* macOS
* Cloud-hosted Windows environments
* Cloud-hosted Linux environments
* Additional AI tooling as required

## Revision History

Version	Date	Notes
1.0	2026-06-03	Initial workstation specification