# HW Laptop Grader v0.1.0 distribution

This is the public, runtime-only distribution for HW Laptop Grader. It is deliberately versioned so loaner laptops download a fixed, reviewable package rather than the latest development branch.

The source repository remains private. This directory contains only the PowerShell scripts, modules, configuration, and license required to run the grader.

## Install and run

Open Windows PowerShell. The bootstrap will request elevation if needed.

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; irm https://raw.githubusercontent.com/bensonlabs/bootstraps/hw-laptop-grader-v0.1.0/distributions/hw-laptop-grader/v0.1.0/scripts/bootstrap.ps1 -OutFile $env:TEMP\hw-laptop-grader-bootstrap.ps1; & $env:TEMP\hw-laptop-grader-bootstrap.ps1 -CollectorUrl 'https://script.google.com/macros/s/AKfycbxFY1EBk3hhVhqSmnTzHIJB0nuIcmvqEjxlDJYxO6RPQD6qg-_-EK3KKojiEW9Ne_N4/exec'
```

Results are saved locally in `C:\ProgramData\HW-Laptop-Grader\Results` as JSON, CSV, and HTML.

## Release contract

- Git tag: `hw-laptop-grader-v0.1.0`
- Bootstrap and subsequent downloads resolve from that tag.
- Future updates are added as a new `vX.Y.Z` directory and tag; existing tags are not changed.
- No credential is embedded in this distribution. The collector URL is passed at runtime.
