# Agent instructions

This repository provisions personal development workstations. Favor reliability, readability, and recoverability over abstraction.

## Architecture rules

- Native PowerShell and Bash remain the execution layer.
- `workstation.yaml` describes desired state. It is not an executable package manager.
- Do not introduce a cross-platform provisioning framework without explicit approval.
- Keep platform-specific package names, repositories, workarounds, and reboot behavior in platform scripts.
- Treat CPU architecture as an explicit compatibility dimension. Do not infer support from emulation or package availability.
- Supported architecture combinations are release requirements; experimental combinations must not block releases; legacy combinations are best effort.
- Installation and verification are separate concerns.
- New installable components require a verification command or an explicit reason why verification is impossible.
- Bootstrap operations should be idempotent whenever practical.
- Existing user configuration must not be overwritten merely to reach a default state.
- Installation must not silently become an upgrade operation.
- Never commit credentials, tokens, private keys, auth cookies, school credentials, or machine-specific secrets.
- Behavioral changes require corresponding validation.
- Prefer incremental changes over rewrites.

## Change order

When evolving the bootstrap architecture:
1. update the desired-state specification and documentation;
2. update validation;
3. update verification/reporting;
4. only then change installation behavior.

A passing CI job proves static contracts and supported runner behavior. It does not prove a clean physical machine rebuild.
