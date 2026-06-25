echo "=============================================================================="
echo " STAGE 2: APPLICATION RUNTIMES & REPOSITORIES"
echo "=============================================================================="
# Configure Flathub Core Repository using root privileges
sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# Install VS Code via Flatpak (more reliable than DNF)
sudo flatpak install flathub com.visualstudio.code -y

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
