#!/usr/bin/env bash
# ==============================================================================
# UNATTENDED AI DEVELOPMENT ENVIRONMENT BOOTSTRAP - FEDORA (DNF5 / KDE)
# Designed to be run remotely via:
# bash <(curl -fsSL https://raw.githubusercontent.com/bensonlabs/bootstraps/main/scripts/bootstrap_fedora.sh)
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

# Install Essential Utilities, Build Tools & Daily Drivers from your macOS layout
sudo dnf5 group install development-tools -y
sudo dnf5 install -y curl wget git gh p7zip p7zip-plugins htop util-linux-user nodejs python3-pip \
                     fastfetch ripgrep bat tree fish zsh

# Set up Starship prompt natively
if ! command -v starship &> /dev/null; then
    echo "   -> Installing starship..."
    curl -sS https://starship.rs/install.sh | sh -s -- -y
fi

# Set up Astral's uv (Python package manager)
if ! command -v uv &> /dev/null; then
    echo "   -> Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
fi

# Configure structural Git speed optimizations
git config --global core.fscache true
git config --global core.preloadindex true
git config --global gc.auto 256

echo "=============================================================================="
echo " STAGE 2: APPLICATION RUNTIMES & REPOSITORIES (FLATPAK)"
echo "=============================================================================="
# Configure Flathub Core Repository using root privileges
sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# Mirrored application suite from your macOS environment (Snap-free)
DEVELOPER_FLATPAKS=(
    "md.obsidian.Obsidian"
    "com.visualstudio.code"
)

echo "Deploying system flatpaks..."
for app in "${DEVELOPER_FLATPAKS[@]}"; do
    # Wrap in subshell block to cleanly bypass 'set -e' constraints on failure
    (sudo flatpak install flathub "$app" -y) || echo "Warning: Failed to install $app, skipping..."
done

# Install Tailscale natively (Kept bare-metal/systemd for core Linux kernel network routing)
if ! command -v tailscale &> /dev/null; then
    echo "   -> Installing Tailscale network engine..."
    sudo dnf5 config-manager --add-repo https://pkgs.tailscale.com/stable/fedora/tailscale.repo || true
    sudo dnf5 install -y tailscale
    sudo systemctl enable --now tailscaled
fi

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
# Core production AI terminals aligned with your ecosystem requirements
sudo npm install -g @anthropic-ai/claude-code
sudo npm install -g @openai/codex
sudo npm install -g gemini-cli

echo "=============================================================================="
echo " STAGE 5: NATIVE BINARY EMULATION"
echo "=============================================================================="
echo "🛠️ Creating custom 'll' system binary wrapper..."
sudo mkdir -p /usr/local/bin
sudo tee /usr/local/bin/ll > /dev/null << 'EOF'
#!/bin/sh
exec ls -laFo --color=auto --group-directories-first "$@"
EOF
sudo chmod +x /usr/local/bin/ll

echo "=============================================================================="
echo " STAGE 6: SYSTEM PRODUCTION VERIFICATION"
echo "=============================================================================="
echo -e "\n--- VERIFYING FEDORA WORKSTATION ENGINE STACK ---"
cat /etc/fedora-release
git --version
gh --version
node --version
npm list -g --depth=0
uv --version
starship --version | head -n 1
ollama --version
echo "------------------------------------------------"

echo "Bootstrap complete! Launch 'fish' or 'zsh' to start coding with your unified utility belt."
echo ""

# Execute Fastfetch to celebrate the clean install and reveal core specs
fastfetch[code]
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
sudo npm install -g @anthropic-ai/claude-code
sudo npm install -g @openai/codex
sudo npm install -g @google/gemini-cli

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
