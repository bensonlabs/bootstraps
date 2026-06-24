# ==============================================================================
# Loaner Tracker -- Dev Environment Bootstrap
# Run from an elevated PowerShell prompt
# ==============================================================================

Set-ExecutionPolicy RemoteSigned -Scope Process -Force
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host "Checking internet connection..." -ForegroundColor Cyan
while (!(Test-Connection -ComputerName 8.8.8.8 -Count 1 -ErrorAction SilentlyContinue)) {
    Write-Host "Waiting for network connectivity..." -ForegroundColor Yellow
    Start-Sleep -Seconds 3
}
Write-Host "Internet connection verified! Proceeding with setup." -ForegroundColor Green

# ==============================================================================
# INSTALLS
# ==============================================================================

winget install --id Microsoft.PowerShell      -e --accept-package-agreements --accept-source-agreements
winget install --id Python.Python.3.13        -e --accept-package-agreements --accept-source-agreements
winget install --id Git.Git                   -e --accept-package-agreements --accept-source-agreements
winget install --id NSSM.NSSM                 -e --accept-package-agreements --accept-source-agreements
winget install --id Google.Chrome             -e --accept-package-agreements --accept-source-agreements
winget install --id Microsoft.VisualStudioCode -e --accept-package-agreements --accept-source-agreements
winget install --id OpenJS.NodeJS.LTS         -e --accept-package-agreements --accept-source-agreements

# ==============================================================================
# PATH + GIT CONFIG + CLAUDE CODE
# ==============================================================================

$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

git config --global user.name "Justin Benson"
git config --global user.email "jbenson.dev@gmail.com"
git config --global core.fscache true
git config --global core.preloadindex true
git config --global gc.auto 256

npm install -g @anthropic-ai/claude-code

$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# ==============================================================================
# VERIFICATION
# ==============================================================================

Write-Host "`n--- Verifying installs ---" -ForegroundColor Cyan
git --version
python --version
node --version
npm list -g @anthropic-ai/claude-code --depth=0
nssm version

Write-Host "`nDone. Next steps:" -ForegroundColor Green
Write-Host "  1. git clone https://github.com/bensonlabs/loaner-tracker.git"
Write-Host "  2. cd loaner-tracker"
Write-Host "  3. python -m venv venv"
Write-Host "  4. .\venv\Scripts\activate"
Write-Host "  5. pip install -r requirements.txt"
Write-Host "  6. claude"
