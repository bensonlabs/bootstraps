#!/usr/bin/env bash

# ==============================================================================
# bootstrap_macOS.sh
# Designed to be run remotely via:
# bash <(curl -fsSL https://raw.githubusercontent.com/bensonlabs/bootstraps/main/scripts/bootstrap_macOS.sh)
# ==============================================================================

# Exit immediately if a command exits with a non-zero status
set -e

echo "🚀 Starting remote macOS Bootstrap Script..."

# ------------------------------------------------------------------------------
# 1. Ensure Homebrew is Installed and Loaded in the Current Session
# ------------------------------------------------------------------------------
if ! command -v brew &> /dev/null; then
    echo "🍺 Homebrew not found. Installing..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Dynamically load brew environment variables based on system architecture
if [ -f /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -f /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi

echo "🍺 Homebrew is ready."

# ------------------------------------------------------------------------------
# 2. Core CLI Tools (Mirrored from your daily driver)
# ------------------------------------------------------------------------------
echo "📦 Installing daily driver CLI tools..."
cli_tools=(
    git
    gh
    node
    uv
    ripgrep
    bat
    tree
    htop
    starship
    fish
    zsh-completions
    gemini-cli
    coreutils       # Required for genuine Linux file mapping (gls)
)

for tool in "${cli_tools[@]}"; do
    if brew list "$tool" &> /dev/null; then
        echo "   -> $tool is already installed. Skipping."
    else
        echo "   -> Installing $tool..."
        brew install "$tool"
    fi
done

# ------------------------------------------------------------------------------
# 3. GUI Applications (Casks)
# ------------------------------------------------------------------------------
echo "🖥️ Installing GUI Applications..."
casks=(
    visual-studio-code
    iterm2
    github
    caffeine
    obsidian
    tailscale
)

for cask in "${casks[@]}"; do
    echo "   -> Installing $cask..."
    brew install --cask --force "$cask"
done

# Force Claude to bypass "App already exists" errors
echo "   -> Overtaking/Installing Claude.app cleanly..."
brew install --cask --force claude

# Safe guard for Gemini Cask (Requires Apple Silicon Architecture + macOS 15+)
OS_VERSION=$(sw_vers -productVersion | cut -d. -f1)

if [[ "$(uname -m)" == "arm64" ]] && [ "$OS_VERSION" -ge 15 ]; then
    echo "   -> Apple Silicon & macOS 15+ detected. Installing native Google Gemini App..."
    brew install --cask --force google-gemini
else
    echo "   -> Skipping Google Gemini desktop cask (Requires Apple Silicon & macOS 15+)."
fi

# ------------------------------------------------------------------------------
# 4. OpenAI Codex CLI Installation
# ------------------------------------------------------------------------------
echo "🤖 Installing OpenAI Codex CLI..."
if ! command -v codex &> /dev/null; then
    echo "   -> Executing non-interactive Codex installer..."
    curl -fsSL https://chatgpt.com/codex/install.sh | env CODEX_NON_INTERACTIVE=1 sh
else
    echo "   -> Codex CLI is already installed."
fi

# ------------------------------------------------------------------------------
# 5. Injecting 'll' as a Native System Binary Command
# ------------------------------------------------------------------------------
echo "🛠️ Creating custom 'll' system binary wrapper..."

# Ensure target local bin directory exists securely
sudo mkdir -p /usr/local/bin

# Build a true native binary wrapper passing parameters cleanly.
sudo tee /usr/local/bin/ll > /dev/null << 'EOF'
#!/bin/sh
exec gls -laFo --color=auto --group-directories-first "$@"
EOF

# Make the raw binary execution file executable by the system root pathing
sudo chmod +x /usr/local/bin/ll

# ------------------------------------------------------------------------------
# 6. macOS System Configuration
# ------------------------------------------------------------------------------
echo "⚙️ Configuring macOS system defaults..."
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write NSGlobalDomain NSWindowResizeTime -float 0.001

# Restart Finder safely
killall Finder &> /dev/null || true

# ------------------------------------------------------------------------------
# Wrap Up
# ------------------------------------------------------------------------------
echo "🎉 Remote Bootstrap complete! Please restart your terminal window or run 'exec zsh' to refresh your environment."
