#!/usr/bin/env bash
# ==============================================================================
# MASTER UNATTENDED AI DEVELOPMENT ENVIRONMENT BOOTSTRAP - UBUNTU DESKTOP (LATEST)
# ==============================================================================
set -e

# Ensure non-interactive frontend to bypass prompts
export DEBIAN_FRONTEND=noninteractive

echo "=============================================================================="
echo " STAGE 1: SYSTEM UPDATES & OPTIMIZATIONS"
echo "=============================================================================="
# Fast mirror adjustments & update sequence
sudo apt-get update && sudo apt-get upgrade -y

# Install Essential Utilities & Build Essential Stack
sudo apt-get install -y curl wget git build-essential software-properties-common apt-transport-https htop fsearch

# GitHub CLI installation repository setup
if ! type -p gh >/dev/null; then
    sudo mkdir -p -m 755 /etc/apt/keyrings
    wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
    sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.p/github-cli.list > /dev/null
    sudo apt-get update
fi
sudo apt-get install -y gh

# Configure Git Performance Overrides
git config --global core.fscache true
git config --global core.preloadindex true
git config --global gc.auto 256

echo "=============================================================================="
echo " STAGE 2: APPLICATION RUNTIMES & REPOSITORIES"
echo "=============================================================================="
# 1. Install VS Code Via Official Microsoft Repo (Avoids Snap performance snags for IDEs)
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
rm -f packages.microsoft.gpg
sudo apt-get update && sudo apt-get install -y code

# 2. Desktop AI Applications via Snap (Native to Ubuntu Desktop Out-of-the-Box)
sudo snap install claude-desktop --beta || echo "Claude desktop not available via snap yet, skipping..."
sudo snap install chatgpt-desktop || echo "ChatGPT desktop not available via snap yet, skipping..."

# 3. Runtimes: Python 3 & Node.js LTS via NodeSource
sudo apt-get install -y python3 python3-pip python3-venv Python3-dev

# Fetch and script-install latest Node.js LTS 
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt-get install -y nodejs

echo "=============================================================================="
echo " STAGE 3: CONTAINERIZATION (DOCKER CE)"
echo "=============================================================================="
# Install official Docker CE repository setup
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Enable and spin up service background
sudo systemctl enable --now docker
sudo usermod -aG docker $USER

echo "=============================================================================="
echo " STAGE 4: GLOBAL AI CLI TOOLS (NPM)"
echo "=============================================================================="
# Install the global AI tools
sudo npm install -g @anthropic-ai/claude-code @openai/codex @google/gemini-cli one-file-context

echo "=============================================================================="
echo " STAGE 5: SYSTEM VERIFICATION"
echo "=============================================================================="
echo -e "\n--- VERIFYING UBUNTU DESKTOP STACK ---"
lsb_release -a
git --version
gh --version
python3 --version
node --version
docker --version
sudo npm list -g --depth=0
echo "----------------------------------------"

echo "Bootstrap complete! Please log out and back in, or reboot your laptop to apply user group changes."
