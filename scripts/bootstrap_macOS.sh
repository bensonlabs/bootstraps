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
    # Using env to bypass interactive prompts where possible
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Dynamically load brew environment variables so the rest of THIS remote session can use it
if [ -f /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -f /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi

echo "🍺 Homebrew is ready."

# ------------------------------------------------------------------------------
# 2. Core CLI Tools
# ------------------------------------------------------------------------------
echo "📦 Installing core CLI tools..."
cli_tools=(git node ripgrep zsh-completions)

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
casks=(visual-studio-code iterm2)

for cask in "${casks[@]}"; do
    echo "   -> Installing $cask..."
    brew install --cask --force "$cask"
done

# Force Claude to bypass "App already exists" errors
echo "   -> Overtaking/Installing Claude.app cleanly..."
brew install --cask --force claude

# ------------------------------------------------------------------------------
# 4. OpenAI Codex CLI Installation
# ------------------------------------------------------------------------------
echo "🤖 Installing OpenAI Codex CLI..."
if ! command -v codex &> /dev/null; then
    echo "   -> Executing non-interactive Codex installer..."
    # Passing the non-interactive flag explicitly to prevent script hangs over curl pipe
    curl -fsSL https://chatgpt.com/codex/install.sh | env CODEX_NON_INTERACTIVE=1 sh
else
    echo "   -> Codex CLI is already installed."
fi

# ------------------------------------------------------------------------------
# 5. macOS System Configuration
# ------------------------------------------------------------------------------
echo "⚙️ Configuring macOS system defaults..."
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write com.apple.finder ShowPathbar -bool true

# Restart Finder safely
killall Finder &> /dev/null || true

# ------------------------------------------------------------------------------
# Wrap Up
# ------------------------------------------------------------------------------
echo "🎉 Remote Bootstrap complete! Please restart your terminal window or run 'exec zsh' to refresh your environment."
