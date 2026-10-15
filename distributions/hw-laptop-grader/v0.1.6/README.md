# HW Laptop Grader v0.1.6

Runtime-only Windows 11 diagnostic distribution for Benson Labs loaner-laptop reassignment.

This version runs Windows' built-in `winsat formal` assessment and records the official `Win32_WinSAT` overall, processor, memory, graphics, 3D graphics, and disk component scores. It may take several minutes, so keep the laptop on AC power and otherwise idle. The run is capped at 15 minutes; an unsupported or incomplete assessment is reported without discarding the other diagnostics.

Run from an elevated Windows PowerShell prompt:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; irm https://raw.githubusercontent.com/bensonlabs/bootstraps/hw-laptop-grader-v0.1.6/distributions/hw-laptop-grader/v0.1.6/scripts/bootstrap.ps1 -OutFile $env:TEMP\hw-laptop-grader-bootstrap.ps1; & $env:TEMP\hw-laptop-grader-bootstrap.ps1 -CollectorUrl 'https://script.google.com/macros/s/AKfycbxFY1EBk3hhVhqSmnTzHIJB0nuIcmvqEjxlDJYxO6RPQD6qg-_-EK3KKojiEW9Ne_N4/exec'
```

The bootstrap downloads only this release-tagged distribution and writes JSON, CSV, and HTML reports locally. The optional Google Sheet collector URL is public endpoint configuration, not a secret.
