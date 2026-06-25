#!/usr/bin/env bash
# ==============================================================================
# UNATTENDED AI DEVELOPMENT ENVIRONMENT BOOTSTRAP - FEDORA (DNF5 / KDE)
# ==============================================================================
set -euo pipefail

echo "=============================================================================="
echo " STAGE 1: SYSTEM UPDATES & OPTIMIZATIONS"
echo "=============================================================================="
sudo tee /etc/dnf/dnf.conf << 'EOF'
[main]
fastestmirror=True
max_parallel_downloads=10
defaultyes=True
EOF

sudo dnf5 upgrade -y

sudo dnf5 group install development-tools -y
sudo dnf5 install -y curl wget git gh p7zip p7zip-plugins htop util-linux-user nodejs python3-pip fastfetch

git config --global core.fscache true
git config --global core.preloadindex true
git config --global gc.auto 256

echo "=============================================================================="
echo " STAGE 2: APPLICATION RUNTIMES & REPOSITORIES"
echo "=============================================================================="
sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

sudo flatpak install flathub com.visualstudio.code -y

echo "=============================================================================="
echo " STAGE 2B: DEVELOPER & PRODUCTIVITY APPLICATIONS"
echo "=============================================================================="
FLATPAK_APPS=(
    "com.brave.Browser"        # Brave browser (use for ChatGPT - no official Linux app exists)
    "com.bitwarden.desktop"    # Bitwarden
    "md.obsidian.Obsidian"     # Obsidian
    "com.slack.Slack"          # Slack
)

echo "Installing productivity flatpaks..."
for app in "${FLATPAK_APPS[@]}"; do
    (sudo flatpak install flathub "$app" -y) || echo "Warning: Failed to install $app, skipping..."
done

# Tailscale via DNF (no reliable Flatpak available)
echo "Installing Tailscale..."
sudo dnf5 install -y tailscale
sudo systemctl enable --now tailscaled

echo "=============================================================================="
echo " STAGE 3: LOCAL AI ENGINE (OLLAMA) - SKIPPED"
echo "=============================================================================="
# Uncomment to enable Ollama
# echo "Downloading and provisioning Ollama..."
# curl -fsSL https://ollama.com/install.sh | sh
# sudo systemctl enable --now ollama

echo "=============================================================================="
echo " STAGE 4: CLOUD AI CLI TOOLING"
echo "=============================================================================="
# Configure user npm prefix - never use sudo with npm
mkdir -p ~/.npm-global
npm config set prefix '~/.npm-global'
echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.bashrc
export PATH="$HOME/.npm-global/bin:$PATH"

# Claude Code via npm
echo "Installing Claude Code..."
npm install -g @anthropic-ai/claude-code

# Zed IDE
echo "Installing Zed IDE..."
curl -fsSL https://zed.dev/install.sh | sh

# Google Antigravity
echo "Testing Google Antigravity runtime..."
npx @google/antigravity --version || echo "Notice: Verify correct Antigravity package name."

echo "=============================================================================="
echo " STAGE 5: SYSTEM PRODUCTION VERIFICATION"
echo "=============================================================================="
echo -e "\n--- VERIFYING FEDORA WORKSTATION ENGINE STACK ---"
cat /etc/fedora-release
git --version
gh --version
node --version
npm list -g --depth=0
flatpak run com.visualstudio.code --version | head -n 1
# ollama --version  # skipped - Ollama not installed
claude --version 2>/dev/null || echo "Claude Code not found in PATH (re-source ~/.bashrc)"
zed --version 2>/dev/null || echo "Zed IDE installed (verify PATH)"
tailscale version
echo "------------------------------------------------"

echo "Bootstrap complete!"
echo ""
fastfetch
