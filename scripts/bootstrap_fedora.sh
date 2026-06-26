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

BASE_PACKAGES=(
    curl
    wget
    git
    gh
    p7zip
    p7zip-plugins
    htop
    util-linux-user
    nodejs
    python3-pip
    fastfetch
    btrfs-progs
    snapper
    btrfs-assistant
    tree
    ripgrep
)

OPTIONAL_PACKAGES=(
    grub-btrfs
)

sudo dnf5 install -y "${BASE_PACKAGES[@]}"

for pkg in "${OPTIONAL_PACKAGES[@]}"; do
    if ! sudo dnf5 install -y "$pkg"; then
        echo "Warning: Optional package $pkg is not available, skipping..."
    fi
done

git config --global core.fscache true
git config --global core.preloadindex true
git config --global gc.auto 256

echo "=============================================================================="
echo " STAGE 2: APPLICATION RUNTIMES & REPOSITORIES"
echo "=============================================================================="
if ! sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo; then
    echo "Warning: Failed to add Flathub remote, skipping Flatpak app installs..."
    SKIP_FLATPAK_INSTALLS=1
else
    SKIP_FLATPAK_INSTALLS=0
fi

if [[ "$SKIP_FLATPAK_INSTALLS" -eq 0 ]]; then
    if ! sudo flatpak install flathub com.visualstudio.code -y; then
        echo "Warning: Failed to install com.visualstudio.code, skipping..."
    fi
fi

echo "=============================================================================="
echo " STAGE 2B: DEVELOPER & PRODUCTIVITY APPLICATIONS"
echo "=============================================================================="
FLATPAK_APPS=(
    "com.brave.Browser"        # Brave browser (use for ChatGPT - no official Linux app exists)
    "com.bitwarden.desktop"    # Bitwarden
    "md.obsidian.Obsidian"     # Obsidian
    "com.slack.Slack"          # Slack
)

if [[ "$SKIP_FLATPAK_INSTALLS" -eq 0 ]]; then
    echo "Installing productivity flatpaks..."
    for app in "${FLATPAK_APPS[@]}"; do
        (sudo flatpak install flathub "$app" -y) || echo "Warning: Failed to install $app, skipping..."
    done
else
    echo "Skipping productivity flatpaks because Flathub could not be configured."
fi

# Tailscale via DNF (no reliable Flatpak available)
echo "Installing Tailscale..."
if sudo dnf5 install -y tailscale; then
    if ! sudo systemctl enable --now tailscaled; then
        echo "Warning: Tailscale installed but tailscaled could not be enabled/started."
    fi
else
    echo "Warning: Failed to install tailscale, skipping service enablement."
fi

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
mkdir -p "$HOME/.npm-global"
npm config set prefix "$HOME/.npm-global"
if ! grep -Fqx 'export PATH="$HOME/.npm-global/bin:$PATH"' "$HOME/.bashrc"; then
    echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> "$HOME/.bashrc"
fi
export PATH="$HOME/.npm-global/bin:$PATH"
hash -r

# Claude Code via npm
echo "Installing Claude Code..."
if npm install -g @anthropic-ai/claude-code; then
    hash -r
else
    echo "Warning: Failed to install Claude Code, skipping..."
fi

# Codex CLI (official OpenAI installer)
echo "Installing Codex CLI..."
if ! (curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_NON_INTERACTIVE=1 sh); then
    echo "Warning: Failed to install Codex CLI, skipping..."
fi
hash -r

# Zed IDE
echo "Installing Zed IDE..."
if ! (curl -fsSL https://zed.dev/install.sh | sh); then
    echo "Warning: Failed to install Zed IDE, skipping..."
fi
hash -r

# Google Antigravity CLI (binary: agy)
echo "Installing Google Antigravity CLI..."
if ! (curl -fsSL https://antigravity.google/cli/install.sh | bash); then
    echo "Warning: Failed to install Google Antigravity CLI, skipping..."
fi
hash -r

# GitHub Copilot CLI
echo "Installing GitHub Copilot CLI..."
if ! (curl -fsSL https://gh.io/copilot-install | bash); then
    echo "Warning: Failed to install GitHub Copilot CLI, skipping..."
fi
hash -r

echo "=============================================================================="
echo " STAGE 5: SYSTEM PRODUCTION VERIFICATION"
echo "=============================================================================="
echo -e "\n--- VERIFYING FEDORA WORKSTATION ENGINE STACK ---"
cat /etc/fedora-release
git --version
gh --version
node --version
npm --version
echo ""
echo "--- NPM GLOBALS ---"
npm list -g --depth=0 || echo "WARN: Unable to list global npm packages"
echo ""
echo "--- AI TOOLING ---"
claude --version 2>/dev/null || echo "WARN: Claude Code not in PATH (run: export PATH=\"\$HOME/.npm-global/bin:\$PATH\")"
codex --version 2>/dev/null || echo "WARN: Codex not in PATH (re-source ~/.bashrc)"
copilot --version 2>/dev/null || echo "WARN: Copilot CLI not in PATH (re-source ~/.bashrc)"
agy --version 2>/dev/null || echo "WARN: Antigravity CLI not in PATH (re-source ~/.bashrc)"
zed --version 2>/dev/null || echo "WARN: Zed not in PATH"
echo ""
echo "--- SYSTEM SERVICES ---"
tailscale version 2>/dev/null || echo "WARN: Tailscale not installed or not in PATH"
echo ""
echo "--- FLATPAKS ---"
flatpak list --app --columns=application | grep -E "visualstudio|brave|bitwarden|obsidian|slack" || echo "WARN: Some flatpaks may be missing"
echo "------------------------------------------------"
echo "Bootstrap complete!"
echo ""
fastfetch
