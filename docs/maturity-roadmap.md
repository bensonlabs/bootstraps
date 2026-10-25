# Bootstrap maturity roadmap

The repository is evolving from installation scripts into workstation configuration as code. The target is deliberately smaller than a general configuration-management system.

## Architecture

`workstation.yaml` is the canonical desired-state specification. Native Bash and PowerShell remain responsible for platform-specific execution.

The lifecycle is:

```text
desired state
  -> inspect machine
  -> calculate missing state
  -> install selected missing components
  -> verify
  -> machine-state.json
```

## Profiles

The specification defines `core`, `developer`, `ai-dev`, `desktop`, and `full`. Profile support should be introduced incrementally. Existing bootstrap defaults must remain compatible until each platform explicitly adopts profiles.

## Operations

Installation, verification, and upgrade are distinct operations.

- **install** converges missing selected components.
- **verify** is read-only and reports conformance.
- **upgrade** must be explicit. It must not be smuggled into ordinary bootstrap execution.

## Personalization boundary

Package installation is separate from personalization. Git identity, editor preferences, shell aliases, desktop preferences, authentication, and application configuration should be optional and should preserve existing configuration.

## Machine-readable reports

Verification should eventually emit `machine-state.json` with platform, selected profile, workstation-spec version, overall status, and per-tool status/version information. Human-readable terminal output remains useful, but automation should not need to scrape it.

## Testing levels

1. Syntax and static contract validation.
2. Dry-run behavior.
3. Verification behavior.
4. Idempotency: a second bootstrap run should make no meaningful changes.
5. Disposable clean-machine or VM rebuild.
6. Post-reboot validation where required.

CI runner success is not equivalent to a clean-machine rebuild.

## Versioning

`workstation_spec_version` identifies the desired workstation state independently of repository commits. Increment it when desired state changes materially.

## Non-goals

Do not add a web dashboard, central database, resident agent, custom package manager, or cross-platform provisioning framework unless a demonstrated requirement emerges.
