#!/usr/bin/env bash
# ==============================================================================
# UNATTENDED AI DEVELOPMENT ENVIRONMENT BOOTSTRAP - UBUNTU (APT)
# Designed to be run remotely via:
# bash <(curl -fsSL https://raw.githubusercontent.com/bensonlabs/bootstraps/main/scripts/bootstrap_ubuntu.sh)
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

# Install Essential Utilities, Build Tools & Daily Drivers from your macOS layout
sudo apt-get install -y build-essential curl wget git gh p7zip-full htop nodejs npm \
                        fastfetch flatpak ripgrep bat tree fish zsh zstd

# Fix Ubuntu's 'batcat' naming quirk so it's globally usable via 'bat'
sudo mkdir -p /usr/local/bin
if [ ! -f /usr/local/bin/bat ] && command -v batcat &> /dev/null; then
    sudo ln -s /usr/bin/batcat /usr/local/bin/bat
fi

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
    curl -fsSL https://tailscale.com/install.sh | sh
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

# Optional contextual helper utilities (Safeguarded from registry name changes)
(sudo npm install -g one-file-context) || echo "Warning: one-file-context failed to install, skipping..."

echo "=============================================================================="
echo " STAGE 5: NATIVE BINARY EMULATION"
echo "=============================================================================="
echo "🛠️ Creating custom 'll' system binary wrapper..."
sudo tee /usr/local/bin/ll > /dev/null << 'EOF'
#!/bin/sh
exec ls -laFo --color=auto --group-directories-first "$@"
EOF
sudo chmod +x /usr/local/bin/ll

echo "=============================================================================="
echo " STAGE 6: SYSTEM PRODUCTION VERIFICATION"
echo "=============================================================================="
echo -e "\n--- VERIFYING UBUNTU WORKSTATION ENGINE STACK ---"
[ -f /etc/os-release ] && grep "PRETTY_NAME" /etc/os-release || lsb_release -d
git --version
gh --version
node --version
npm list -g --depth=0
uv --version
starship --version | head -n 1
ollama --version
echo "------------------------------------------------"

echo "Bootstrap complete! Pull down an open-source model using 'ollama run llama3' or launch 'fish' / 'zsh' to start coding."
echo ""

# Execute Fastfetch to celebrate the clean install and reveal core specs
fastfetch# Download Microsoft GPG signing key and add the VS Code repository
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
sudo npm install -g --unsafe-perm=true @google/gemini-cli

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
echo "------------------------------------------------"

echo "Bootstrap complete!"

# Execute Fastfetch to celebrate the clean install and reveal core specs
fastfetch
