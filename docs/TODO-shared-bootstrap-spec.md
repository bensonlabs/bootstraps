# TODO: Shared bootstrap specification

## Goal

Introduce a small declarative YAML specification for tools and packages shared across Windows, Fedora, Ubuntu, and macOS.

This should establish one canonical definition of the desired workstation without replacing the native PowerShell and Bash implementations.

## Initial candidate

```yaml
ai_tools:
  claude:
    npm: "@anthropic-ai/claude-code"
    command: claude
  codex:
    npm: "@openai/codex"
    command: codex

common_tools:
  - git
  - gh
  - node
  - python
  - ripgrep
  - fastfetch
```

## Design constraint

Keep platform-specific installation logic in the existing scripts. The YAML should describe desired state, not become a new cross-platform provisioning framework.

## Acceptance criteria

- Shared tools have one canonical definition.
- Existing bootstrap behavior remains unchanged initially.
- Platform-specific package names and exceptions remain supported.
- CI validates the specification.
- Avoid premature abstraction of logging, package managers, or platform-specific provisioning.

## Suggested Codex task

Review the current bootstrap scripts and propose the smallest implementation that introduces this shared specification without changing existing provisioning behavior. Prefer an incremental migration and preserve native platform-specific logic.
