# Platform and architecture support matrix

Architecture is an explicit support dimension. A package installing under emulation does not by itself establish support.

| Platform | Architecture | Status | Install | Dry run | Static CI | Verify/report | Idempotency test | Clean-machine tested |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Windows 11 | x86_64 | Supported | Yes | Yes | Yes | Yes | Planned | Not recorded |
| Windows 11 | ARM64 | Experimental | Blocked | Preview only | No | Yes | No | Not recorded |
| Fedora | x86_64 | Supported | Yes | Yes | Yes | Yes | Planned | Not recorded |
| Fedora | ARM64 | Experimental | Blocked | Preview only | No | Yes | No | Not recorded |
| Ubuntu | x86_64 | Supported | Yes | Yes | Yes | Yes | Planned | Not recorded |
| Ubuntu | ARM64 | Experimental | Blocked | Preview only | No | Yes | No | Not recorded |
| macOS | ARM64 | Supported | Yes | Yes | Yes | Yes | Planned | Not recorded |
| macOS | x86_64 | Legacy | Best effort | Yes | No | Yes | No | Not recorded |

## Authoritative integration targets

The required clean-machine matrix is intentionally limited to:

- Windows 11 x86_64
- Fedora x86_64
- Ubuntu x86_64
- macOS ARM64

Experimental architectures may be developed and tested without blocking releases. Legacy architectures receive best-effort compatibility but do not expand the required integration matrix.

"Clean-machine tested" is separate from CI. Update that field only after the bootstrap has been exercised against a clean installation or disposable VM and the result recorded.

## Future promotion

ARM64 Linux should be promoted from experimental when it becomes an actual workstation requirement and receives clean-machine integration coverage. Support status should follow tested requirements, not theoretical package availability.

## Bootstrap architecture preflight

Every bootstrap checks CPU architecture before creating logs, showing the
component checklist, or running installation steps. Unknown architectures stop
with an error, including in dry-run mode.

- Windows, Fedora, and Ubuntu install on x86_64. ARM64 is experimental: dry runs
  print a warning and show the plan, but installation stops before making changes.
  This preserves the existing Linux installation limits and applies the same
  boundary to Windows. Dry-run output does not establish package availability.
- macOS installs on native ARM64. Intel x86_64 continues with a legacy/best-effort
  warning. Apple Silicon running a Rosetta shell stops with instructions to rerun
  in a native ARM64 shell rather than being classified as Intel hardware.
- Linux/macOS architecture aliases `amd64` and `aarch64` normalize to `x86_64` and
  `arm64`. Windows queries the processor's native architecture through CIM instead
  of inferring support from the architecture of the PowerShell process.

Use `--all --dry-run` for Bash scripts or `-All -DryRun` for Windows to preview a
plan. Existing OS/version and package-manager checks still apply to installation.
ARM64 installation support can be developed separately without expanding the
required release matrix.
