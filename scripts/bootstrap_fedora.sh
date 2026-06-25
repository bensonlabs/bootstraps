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
# Configure Flathub Core Repository using root privileges
sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# Install VS Code via Flatpak (more reliable than DNF)
sudo flatpak install flathub com.visualstudio.code -y

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
# Claude Code - fetch binary directly
echo "Installing Claude Code CLI..."
mkdir -p ~/.local/bin
curl -fsSL https://storage.googleapis.com/claude-releases/claude-code/latest/claude-code-linux-x64 \
  -o ~/.local/bin/claude-code
chmod +x ~/.local/bin/claude-code

# Zed IDE - fetch binary
echo "Installing Zed IDE..."
curl -fsSL https://zed.dev/install.sh | sh

# Google Antigravity - validate npx call (confirm correct package name)
echo "Testing Google Antigravity runtime..."
npx @google/antigravity --version || echo "Notice: Antigravity package name may differ; verify with 'npx @google/antigravity --help'"

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
