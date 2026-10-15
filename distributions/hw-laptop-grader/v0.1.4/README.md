# HW Laptop Grader v0.1.4

Runtime-only Windows 11 diagnostic distribution for Benson Labs loaner-laptop reassignment.

This version records Windows activation status as a privacy-safe result: `LICENSED`, `UNLICENSED`, a grace state, notification state, or `UNAVAILABLE`. It does not collect or submit a Windows product key, activation identifier, or account information.

Run from an elevated Windows PowerShell prompt:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; irm https://raw.githubusercontent.com/bensonlabs/bootstraps/hw-laptop-grader-v0.1.4/distributions/hw-laptop-grader/v0.1.4/scripts/bootstrap.ps1 -OutFile $env:TEMP\hw-laptop-grader-bootstrap.ps1; & $env:TEMP\hw-laptop-grader-bootstrap.ps1 -CollectorUrl 'https://script.google.com/macros/s/AKfycbxFY1EBk3hhVhqSmnTzHIJB0nuIcmvqEjxlDJYxO6RPQD6qg-_-EK3KKojiEW9Ne_N4/exec'
```

The bootstrap downloads only this release-tagged distribution and writes JSON, CSV, and HTML reports locally. The optional Google Sheet collector URL is public endpoint configuration, not a secret.
