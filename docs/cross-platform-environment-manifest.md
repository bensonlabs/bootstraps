# Cross-Platform Environment Manifest

This repository aims to reproduce the same practical AI development environment across Ubuntu, Fedora, macOS, and Windows.

## Principles

- Prefer the same tools across all operating systems whenever technically feasible.
- Allow platform-specific installation methods while preserving the same end-user commands and workflows.
- Keep platform-only tools clearly separated from cross-platform requirements.
- Treat a clean VM or snapshot restore as the preferred validation workflow.

## Required Cross-Platform Core CLI Tools

These should be present on all four platforms.

| Category | Tool | Expected command |
|---|---|---|
| Core CLI | Git | `git` |
| Core CLI | GitHub CLI | `gh` |
| Core CLI | Node.js | `node` |
| Core CLI | npm | `npm` |
| Core CLI | Python | `python` or `python3` |
| Core CLI | pip | `pip` or `pip3` |
| Core CLI | ripgrep | `rg` |
| Core CLI | fastfetch | `fastfetch` |
| Core CLI | 7-Zip family | `7z` |

## Required Cross-Platform AI CLI Tools

These should be present on all four platforms.

| Tool | Expected command |
|---|---|
| Claude Code | `claude` |
| Codex CLI | `codex` |
| GitHub Copilot CLI | `copilot` |
| Google Antigravity CLI | `agy` |
| one-file-context | `one-file-context` |

## Required Cross-Platform GUI Applications

These should be installed on all four platforms where packaging is available.

| Application | Ubuntu | Fedora | macOS | Windows |
|---|---|---|---|---|
| Visual Studio Code | yes | yes | yes | yes |
| Slack | yes | yes | yes | yes |
| Bitwarden | yes | yes | yes | yes |
| Obsidian | yes | yes | yes | yes |
| ChatGPT | yes | yes | yes | yes |
| Claude Desktop | yes | yes | yes | yes |
| Zed | yes | yes | yes | yes |
| Google Antigravity IDE/app | yes* | yes* | yes* | yes |
| GitHub Copilot desktop app | yes* | yes* | yes* | yes |

`*` Required where packaging or a reliable unattended installer path is available. If not scriptable on a given platform, treat as a required manual follow-up for full parity.

## Optional Cross-Platform GUI Applications

These are useful, but not required for strict parity.

| Application | Ubuntu | Fedora | macOS | Windows |
|---|---|---|---|---|
| Brave | optional | optional | optional | optional |
| GitHub Desktop | optional | optional | yes | yes |

## Platform-Specific Tools

These are intentionally platform-specific and do not need parity.

| Platform | Tooling |
|---|---|
| Windows | PowerToys, Windows Terminal, WSL bootstrap |
| macOS | iTerm2, Finder defaults, ll wrapper |
| Fedora | Tailscale, btrfs helpers |
| Ubuntu | desktop package variants by DE |

## Git Configuration Parity

These settings should be applied everywhere:

- `git config --global core.fscache true`
- `git config --global core.preloadindex true`
- `git config --global gc.auto 256`

User identity may remain machine- or user-specific.

## Current Gaps To Close

### Highest priority

- Ensure Google Antigravity IDE/app is installed on every platform where packaging or a reliable unattended installer exists.
- Ensure GitHub Copilot desktop app is installed on every platform where packaging or a reliable unattended installer exists.
- Where either app is not yet scriptable on a platform, document the required manual follow-up step.
- Keep the final user-facing commands consistent for required CLI tooling.

### Verification parity

Every platform should verify these commands when applicable:

- `git --version`
- `gh --version`
- `node --version`
- `npm --version`
- `claude --version`
- `codex --version`
- `copilot --version`
- `agy --version`
- `one-file-context --help` or command presence
- `fastfetch`

### GUI parity review

The scripts should converge on this GUI baseline:

- Visual Studio Code
- Slack
- Bitwarden
- Obsidian
- ChatGPT
- Claude Desktop
- Zed
- Google Antigravity IDE/app
- GitHub Copilot desktop app

Brave may remain optional.

## Recommended Test Workflow

For each operating system:

1. Restore a clean snapshot.
2. Run the bootstrap once.
3. Capture terminal output and the generated log file.
4. Verify all required commands are present.
5. Verify GUI application presence.
6. Note any manual follow-up steps required for app installs that are not yet scriptable.
7. Roll back the snapshot before the next script revision.
