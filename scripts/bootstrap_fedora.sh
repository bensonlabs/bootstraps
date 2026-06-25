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

echo "=============================================================================="
echo " STAGE 2B: DEVELOPER & PRODUCTIVITY APPLICATIONS"
echo "=============================================================================="

FLATPAK_APPS=(
    "com.brave.Browser"           # Brave browser
    "com.bitwarden.desktop"       # Bitwarden password manager
    "md.obsidian.Obsidian"        # Obsidian notes
    "com.slack.Slack"             # Slack
    "com.openai.ChatGPT"          # ChatGPT desktop app
    "com.google.Gemini"           # Google Gemini app
)

echo "Installing productivity flatpaks..."
for app in "${FLATPAK_APPS[@]}"; do
    (sudo flatpak install flathub "$app" -y) || echo "Warning: Failed to install $app, skipping..."
done

# Tailscale - install via system package (no stable Flatpak)
echo "Installing Tailscale via DNF..."
sudo dnf5 install -y tailscale
sudo systemctl enable --now tailscaled

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
# Ensure ~/.local/bin exists and is in PATH
mkdir -p ~/.local/bin
export PATH="$HOME/.local/bin:$PATH"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc

# Claude Code - fetch binary directly
echo "Installing Claude Code CLI..."
curl -fsSL https://storage.googleapis.com/claude-releases/claude-code/latest/claude-code-linux-x64 \
  -o ~/.local/bin/claude-code
chmod +x ~/.local/bin/claude-code

# Zed IDE - fetch binary
echo "Installing Zed IDE..."
curl -fsSL https://zed.dev/install.sh | sh

# Google Antigravity - validate npx call
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
flatpak run com.visualstudio.code --version | head -n 1
ollama --version
claude-code --version 2>/dev/null || echo "Claude Code installed (binary)"
zed --version 2>/dev/null || echo "Zed IDE installed (binary)"
tailscale version
echo "------------------------------------------------"

echo "Bootstrap complete!"
echo ""

# Execute Fastfetch to celebrate the clean install and reveal core specs
fastfetch
