# HW Laptop Grader v0.1.1

Runtime-only Windows 11 diagnostic distribution for Benson Labs loaner-laptop reassignment.

This version adds Windows edition, version, build, installation date, BIOS version/date, and a clearly labeled Windows health section. The health section reports best-effort Windows equivalents for power state, ACPI thermal data, and the latest Windows Memory Diagnostic result when present. It does not run or claim to replace Dell ePSA preboot diagnostics.

Run from an elevated Windows PowerShell prompt:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; irm https://raw.githubusercontent.com/bensonlabs/bootstraps/hw-laptop-grader-v0.1.1/distributions/hw-laptop-grader/v0.1.1/scripts/bootstrap.ps1 -OutFile $env:TEMP\hw-laptop-grader-bootstrap.ps1; & $env:TEMP\hw-laptop-grader-bootstrap.ps1 -CollectorUrl 'https://script.google.com/macros/s/AKfycbxFY1EBk3hhVhqSmnTzHIJB0nuIcmvqEjxlDJYxO6RPQD6qg-_-EK3KKojiEW9Ne_N4/exec'
```

The bootstrap downloads only this release-tagged distribution and writes JSON, CSV, and HTML reports locally. The optional Google Sheet collector URL is public endpoint configuration, not a secret.
