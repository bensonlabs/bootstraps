Write-Host "Exporting Winget packages..."
winget export -o exports/winget-export.json

Write-Host "Exporting Git configuration..."
git config --list > exports/git-config.txt

Write-Host "Exporting VS Code extensions..."
code --list-extensions > exports/vscode-extensions.txt

Write-Host "Exporting Python packages..."
pip freeze > exports/python-packages.txt

Write-Host "Exporting npm packages..."
npm list -g --depth=0 > exports/npm-global-packages.txt

Write-Host "Inventory complete."
