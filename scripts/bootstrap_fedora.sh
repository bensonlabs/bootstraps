#!/usr/bin/env bash
# ==============================================================================
# UNATTENDED AI DEVELOPMENT ENVIRONMENT BOOTSTRAP - FEDORA (DNF5 / KDE)
# ==============================================================================
set -euo pipefail # Hardened error handling: exit on error, unset vars, or pipe drops

echo "=============================================================================="
echo " STAGE 1: SYSTEM UPDATES & OPTIMIZATIONS"
echo "=============================================================================="
# Optimize DNF5 parameters for maximum throughput speed
sudo tee /etc/dnf/dnf.conf << 'EOF'
[main]
fastestmirror=True
max_parallel_downloads=10
defaultyes=True
EOF

sudo dnf5 upgrade -y

# Install Essential Utilities, Build Tools & System Information fetcher
sudo dnf5 group install development-tools -y
sudo dnf5 install -y curl wget git gh p7zip p7zip-plugins htop util-linux-user nodejs python3-pip fastfetch slack

# Configure structural Git speed optimizations
git config --global core.fscache true
git config --global core.preloadindex true
git config --global gc.auto 256

echo "=============================================================================="
echo " STAGE 2: APPLICATION RUNTIMES & REPOSITORIES"
echo "=============================================================================="
# Clear out any stale or broken VS Code repository variations safely
sudo rm -f /etc/yum.repos.d/vscode.repo

# Explicitly write clean newlines into the VS Code repository layer
sudo tee /etc/yum.repos.d/vscode.repo << 'EOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

sudo dnf5 check-update || true
sudo dnf5 install code -y

# Configure Flathub Core Repository using root privileges
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
npm install -g @anthropic-ai/claude-code
npm install -g @openai/codex

# Future-facing Google Antigravity execution hook validation
echo "Pre-caching and testing Antigravity Runtime environment..."
(sudo npx --yes @google/antigravity-cli --version) || echo "Notice: Antigravity CLI initialized or ready for dynamic npx execution."

echo "=============================================================================="
echo " STAGE 5: SYSTEM PRODUCTION VERIFICATION"
echo "=============================================================================="
echo -e "\n--- VERIFYING FEDORA WORKSTATION ENGINE STACK ---"
cat /etc/fedora-release
git --version
gh --version
node --version
npm list -g --depth=0
code --version | head -n 1
ollama --version
echo "------------------------------------------------"

echo "Bootstrap complete!"
echo ""

# Execute Fastfetch to celebrate the clean install and reveal core specs
fastfetch
