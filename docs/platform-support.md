# Platform and architecture support matrix

Architecture is an explicit support dimension. A package installing under emulation does not by itself establish support.

| Platform | Architecture | Status | Install | Dry run | Static CI | Verify/report | Idempotency test | Clean-machine tested |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Windows 11 | x86_64 | Supported | Yes | Yes | Yes | Yes | Planned | Not recorded |
| Windows 11 | ARM64 | Experimental | Not guaranteed | Not guaranteed | No | Yes | No | Not recorded |
| Fedora | x86_64 | Supported | Yes | Yes | Yes | Yes | Planned | Not recorded |
| Fedora | ARM64 | Experimental | Not guaranteed | Not guaranteed | No | Yes | No | Not recorded |
| Ubuntu | x86_64 | Supported | Yes | Yes | Yes | Yes | Planned | Not recorded |
| Ubuntu | ARM64 | Experimental | Not guaranteed | Not guaranteed | No | Yes | No | Not recorded |
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
