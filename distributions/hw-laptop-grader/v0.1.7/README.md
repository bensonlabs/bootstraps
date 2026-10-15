# HW Laptop Grader v0.1.7

Runtime-only Windows 11 diagnostic distribution for Benson Labs loaner-laptop reassignment.

This version removes WinSAT and adds practical reassignment-readiness evidence: GPU/driver and display details, free system-drive capacity, BitLocker status, and detected camera, audio, keyboard, touchpad, and Wi-Fi hardware. It identifies candidate loaner roles only after automated evidence is clean, then requires an operator to confirm camera, microphone, speakers, keyboard, touchpad, Wi-Fi, and AC charging in person.

Run from an elevated Windows PowerShell prompt:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; irm https://raw.githubusercontent.com/bensonlabs/bootstraps/hw-laptop-grader-v0.1.7/distributions/hw-laptop-grader/v0.1.7/scripts/bootstrap.ps1 -OutFile $env:TEMP\hw-laptop-grader-bootstrap.ps1; & $env:TEMP\hw-laptop-grader-bootstrap.ps1 -CollectorUrl 'https://script.google.com/macros/s/AKfycbxFY1EBk3hhVhqSmnTzHIJB0nuIcmvqEjxlDJYxO6RPQD6qg-_-EK3KKojiEW9Ne_N4/exec'
```

The bootstrap downloads only this release-tagged distribution and writes JSON, CSV, and HTML reports locally. The optional Google Sheet collector URL is public endpoint configuration, not a secret.
