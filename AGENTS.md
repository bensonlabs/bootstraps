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

## The bootstraps page

- `site/index.md` is https://bensonlabs.org/bootstraps/, the address people type to reach these
  commands. When a bootstrap command changes (a script's URL or tag, its flags, a new platform),
  update the page in the same pull request.
- Keep every bootstrap on that one page (owner decision, 2026-11-08: no tiles to click through).
- Releases named `vX.Y.Z` are the page's (`tools/pack.py`, `.github/workflows/release.yml`). Don't
  publish GitHub releases for anything else here; the grader uses tags only.
- `.github/workflows/release.yml`, `tools/next_version.py`, `tools/check_shared.py` (and its test)
  and three functions in `tools/pack.py` are identical in bensonlabs/games and bensonlabs/projects.
  What differs per repo comes from the repository's name. The Site page workflow fails a pull
  request when a copy differs (`tools/check_shared.py`). To change one, make the same change in all
  three repos on one branch name, push those branches, then open the pull requests.
