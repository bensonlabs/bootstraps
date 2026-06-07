#!/usr/bin/env bash
# ==============================================================================
# MASTER UNATTENDED AI DEVELOPMENT ENVIRONMENT BOOTSTRAP - FEDORA WORKSTATION (KDE)
# ==============================================================================
set -e # Exit immediately if a command exits with a non-zero status

echo "=============================================================================="
echo " STAGE 1: SYSTEM UPDATES & OPTIMIZATIONS"
echo "=============================================================================="
# Optimize DNF performance (Fastest mirror, parallel downloads)
echo -e "[main]\nfastestmirror=True\nmax_parallel_downloads=10\ndefaultyes=True" | sudo tee -a /etc/dnf/dnf.conf

# Fully update the system
sudo dnf upgrade --refresh -y

# Install Essential Utilities & Build Tools
sudo dnf5 group install development-tools -y
sudo dnf5 install -y curl wget git gh p7zip p7zip-plugins htop util-linux-user

# Configure Git Performance Overrides
git config --global core.fscache true
git config --global core.preloadindex true
git config --global gc.auto 256

echo "=============================================================================="
echo " STAGE 2: APPLICATION RUNTIMES & REPOSITORIES"
echo "=============================================================================="
# 1. Install VS Code Repo and Package
sudo tee /etc/yum.repos.d/vscode.repo << 'EOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

# 2. Setup Flatpak & Flathub (Crucial for desktop applications on Fedora KDE)
sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
sudo flatpak update

# Install GUI Apps via Flatpak
flatpak install flathub com.github.Donadigo.Edict -y       # Everything alternative (FSearch)
flatpak install flathub com.anthropic.Claude -y           # Anthropic Claude Desktop
flatpak install flathub com.openai.ChatGPT -y            # OpenAI ChatGPT Desktop

# 3. Install Runtimes (Python 3.13 & Node.js LTS via Fedora Repos)
sudo dnf install -y python3.13 python3.13-pip python3.13-devel nodejs npm

echo "=============================================================================="
echo " STAGE 3: CONTAINERIZATION (DOCKER CE)"
echo "=============================================================================="
# Add official Docker Repository
sudo dnf config-manager addrepo --url https://download.docker.com/linux/fedora/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Enable and start Docker system service
sudo systemctl enable --now docker

# Add current non-root user to the docker group (takes effect after log out/in)
sudo usermod -aG docker $USER

echo "=============================================================================="
echo " STAGE 4: GLOBAL AI CLI TOOLS (NPM)"
echo "=============================================================================="
# Install the exact matching global AI CLI packages
sudo npm install -g @anthropic-ai/claude-code @openai/codex @google/gemini-cli one-file-context

echo "=============================================================================="
echo " STAGE 5: SYSTEM VERIFICATION"
echo "=============================================================================="
echo -e "\n--- VERIFYING FEDORA WORKSTATION STACK ---"
git --version
gh --version
python3.13 --version
node --version
docker --version
sudo npm list -g --depth=0
echo "------------------------------------------"

echo "Bootstrap complete! Please log out and back in, or reboot your laptop to apply user group changes."
