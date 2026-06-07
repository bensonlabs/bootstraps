#!/usr/bin/env bash
# ==============================================================================
# UNATTENDED AI DEVELOPMENT ENVIRONMENT BOOTSTRAP - FEDORA (DNF5 / KDE)
# ==============================================================================
set -e # Terminate immediately if any individual pipeline fails

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

# Install Essential Utilities & Build Tools using proper DNF5 canonical group ID
sudo dnf5 group install development-tools -y
sudo dnf5 install -y curl wget git gh p7zip p7zip-plugins htop util-linux-user nodejs python3-pip

# Configure structural Git speed optimizations
git config --global core.fscache true
git config --global core.preloadindex true
git config --global gc.auto 256

echo "=============================================================================="
echo " STAGE 2: APPLICATION RUNTIMES & REPOSITORIES"
echo "=============================================================================="
# Clear out any stale or broken VS Code repository variations
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

# Hardened Flatpak validation block (easily allows you to add future developer Flatpaks)
DEVELOPER_FLATPAKS=(
    "org.gimp.GIMP" # Left as an example; remove or swap out as needed!
)

echo "Deploying system flatpaks..."
for app in "${DEVELOPER_FLATPAKS[@]}"; do
    # Adding || true guarantees individual flatpak dropouts won't kill the script execution
    sudo flatpak install flathub "$app" -y || echo "Warning: Failed to install $app, skipping..."
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

# Optional contextual helper utilities (Will log a warning instead of breaking the script)
sudo npm install -g one-file-context || echo "Warning: one-file-context failed to install, skipping..."
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

echo "Bootstrap complete! Pull down an open-source model using 'ollama run llama3' to start coding."
