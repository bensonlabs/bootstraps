# HW Laptop Grader v0.1.3

Runtime-only Windows 11 diagnostic distribution for Benson Labs loaner-laptop reassignment.

This version explicitly promotes the CPU model, maximum clock speed, and current clock speed into the CSV, HTML, and Google Sheet results summaries. Maximum speed is the processor's WMI-reported maximum; current speed is a point-in-time reading that may vary with load and power management.

Run from an elevated Windows PowerShell prompt:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; irm https://raw.githubusercontent.com/bensonlabs/bootstraps/hw-laptop-grader-v0.1.3/distributions/hw-laptop-grader/v0.1.3/scripts/bootstrap.ps1 -OutFile $env:TEMP\hw-laptop-grader-bootstrap.ps1; & $env:TEMP\hw-laptop-grader-bootstrap.ps1 -CollectorUrl 'https://script.google.com/macros/s/AKfycbxFY1EBk3hhVhqSmnTzHIJB0nuIcmvqEjxlDJYxO6RPQD6qg-_-EK3KKojiEW9Ne_N4/exec'
```

The bootstrap downloads only this release-tagged distribution and writes JSON, CSV, and HTML reports locally. The optional Google Sheet collector URL is public endpoint configuration, not a secret.
