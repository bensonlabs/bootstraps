#!/usr/bin/env bash
# ==============================================================================
# UNATTENDED AI DEVELOPMENT ENVIRONMENT BOOTSTRAP - UBUNTU (APT / NO-SNAP)
# ==============================================================================
set -euo pipefail # Hardened error handling: exit on error, unset vars, or pipe drops

echo "=============================================================================="
echo " STAGE 1: SYSTEM UPDATES & OPTIMIZATIONS"
echo "=============================================================================="
# Optimize APT parameters for faster parallel downloading
sudo tee /etc/apt/apt.conf.d/99parallel-downloads << 'EOF'
APT::Periodic::Enable "0";
Binary::apt::APT::Keep-Downloaded-Packages "true";
EOF

# Update package lists and perform a non-interactive system upgrade
sudo apt-get update
sudo apt-get dist-upgrade -y

# Install Essential Utilities, Build Tools & System Information fetcher
sudo apt-get install -y build-essential curl wget git gh p7zip-full htop nodejs npm python3-pip fastfetch flatpak zstd

# Configure structural Git speed optimizations
git config --global core.fscache true
git config --global core.preloadindex true
git config --global gc.auto 256

echo "=============================================================================="
echo " STAGE 2: APPLICATION RUNTIMES & REPOSITORIES (NATIVE ONLY)"
echo "=============================================================================="
# Clear out any stale or broken VS Code repository variations safely
sudo rm -f /etc/apt/sources.list.d/vscode.list
sudo rm -f /etc/apt/keyrings/packages.microsoft.gpg
sudo rm -f /etc/apt/preferences.d/vscode

# Download Microsoft GPG signing key and add the VS Code repository
sudo mkdir -p /etc/apt/keyrings
curl -fSsL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/keyrings/packages.microsoft.gpg > /dev/null

sudo tee /etc/apt/sources.list.d/vscode.list << 'EOF'
deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main
EOF

# Strict Apt Pinning: Force apt to prefer the Microsoft repo over Ubuntu's Snap wrapper
sudo tee /etc/apt/preferences.d/vscode << 'EOF'
Package: code
Pin: origin packages.microsoft.com
Pin-Priority: 1001
EOF

# Refresh package index and install VS Code (.deb native binary)
sudo apt-get update
sudo apt-get install -y code

# Configure Flathub Core Repository using root privileges (Alternative to Snap Store)
sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# Hardened Flatpak validation block (ready for future dev tools if needed)
DEVELOPER_FLATPAKS=(
    "org.gimp.GIMP"
)

echo "Deploying system flatpaks..."
for app in "${DEVELOPER_FLATPAKS[@]}"; do
    # Wrap in subshell block to cleanly bypass 'set -e' constraints on failure
    (sudo flatpak install flathub "$app" -y) || echo "Warning: Failed to install $app, skipping..."
done

echo "=============================================================================="
echo " STAGE 3: LOCAL AI ENGINE DEPLOYMENT (OLLAMA)"
echo "=============================================================================="
echo "Downloading and provisioning bare-metal Linux Ollama subsystem..."
curl -fsSL https://ollama.com/install.sh | sh

# Enable and start the systemd service so Ollama boots with the machine
sudo systemctl enable --now ollama

echo "=============================================================================="
echo " STAGE 4: CLOUD AI CLI TOOLING EMISSION"
echo "=============================================================================="
# Core production AI terminals (Crucial - script will stop if these fail)
sudo npm install -g --unsafe-perm=true @anthropic-ai/claude-code
sudo npm install -g --unsafe-perm=true @openai/codex

# PROVISION GOOGLE ANTIGRAVITY CLI (Replaces legacy Node gemini-cli)
echo "Downloading and provisioning Google Antigravity CLI..."
curl -fsSL https://antigravity.google/cli/install.sh | bash

# Optional contextual helper utilities (Fixed using --unsafe-perm=true permission bypass)
(sudo npm install -g --unsafe-perm=true one-file-context) || echo "Warning: one-file-context failed to install, skipping..."

echo "=============================================================================="
echo " STAGE 5: SYSTEM PRODUCTION VERIFICATION"
echo "=============================================================================="
echo -e "\n--- VERIFYING UBUNTU WORKSTATION ENGINE STACK ---"
lsb_release -d
git --version
gh --version
node --version
npm list -g --depth=0
code --version | head -n 1
ollama --version
# Check the newly minted Go-binary version alias for Antigravity
if command -v agy &> /dev/null; then
    agy --version 2>&1 | head -n 1
else
    echo "Antigravity CLI: Installation verify pending reboot/source profile"
fi
echo "------------------------------------------------"

echo "Bootstrap complete!"

# Execute Fastfetch to celebrate the clean install and reveal core specs
fastfetch
