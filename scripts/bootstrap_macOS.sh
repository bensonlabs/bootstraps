#!/usr/bin/env zsh
# ==============================================================================
# MASTER UNATTENDED AI DEVELOPMENT ENVIRONMENT BOOTSTRAP - MACOS TAHOE (v26)
# ==============================================================================
set -e # Terminate immediately if any individual pipeline fails

echo "=============================================================================="
echo " STAGE 1: XCODE TOOLS & HOMEBREW DEPLOYMENT"
echo "=============================================================================="

# Core compilation requirement checking
if ! xcode-select -p &>/dev/null; then
    echo "Xcode Command Line Tools missing. Triggering system framework install..."
    xcode-select --install
    echo "------------------------------------------------------------------------"
    echo "IMPORTANT: Complete the visual Apple installer prompt overlay."
    echo "Once complete, press ANY KEY in this terminal window to resume bootstrap..."
    echo "------------------------------------------------------------------------"
    read -n 1 -s -r
fi

# Unattended Homebrew installation setup
if ! type -p brew >/dev/null; then
    echo "Installing Homebrew package ecosystem..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Dynamically patch paths for the remaining active script steps
if [ -f /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    eval "$(/usr/local/bin/brew shellenv)"
fi

# Suppress analytic reporting pings for optimized deployment execution
export HOMEBREW_NO_ANALYTICS=1
brew update

echo "=============================================================================="
echo " STAGE 2: SYSTEM TOOLING, RUNTIMES & GIT ENGINE"
echo "=============================================================================="
# Install core platform binaries and the explicit Python 3.13 landscape
brew install git gh coreutils htop node python@3.13 uv

# Configure structural Git speed optimizations
git config --global core.fscache true
git config --global core.preloadindex true
git config --global gc.auto 256

echo "=============================================================================="
echo " STAGE 3: APPLICATION DESKTOP CASKS & LOCAL AI CORE"
echo "=============================================================================="
# Desktop development targets and AI application frameworks
brew install --cask visual-studio-code
brew install --cask docker                 # Container landscape hypervisor
brew install --cask claude                 # Official Anthropic app shell
brew install --cask chatgpt                # Official OpenAI native desktop app
brew install --cask alfred                 # Core local index search matching 'Everything'
brew install --cask ollama                 # Hardware-optimized GGUF local LLM runner

echo "=============================================================================="
echo " STAGE 4: OMLX & MLX DEPLOYMENT ARCHITECTURE"
echo "=============================================================================="
echo "Deploying oMLX core via Homebrew taps..."
brew tap jundot/omlx https://github.com/jundot/omlx
brew install omlx

# Optional: Add Model Context Protocol (MCP) support natively into the oMLX layer
/opt/homebrew/opt/omlx/libexec/bin/pip install mcp --quiet || echo "Skipping standalone oMLX-MCP bind step."

echo "=============================================================================="
echo " STAGE 5: CLOUD & LOCAL AI CLI TOOLING EMISSION"
echo "=============================================================================="
# Global deployment of structural Node-based AI terminals
sudo npm install -g @anthropic-ai/claude-code @openai/codex @google/gemini-cli one-file-context

# Use uv to guarantee global Python management frameworks are isolated safely
uv tool install shell-gpt --force

echo "=============================================================================="
echo " STAGE 6: SHELL RUNTIME PATH & ENVIRONMENT SYNC"
echo "=============================================================================="
PROFILE_FILE="$HOME/.zshrc"
[ ! -f "$PROFILE_FILE" ] && touch "$PROFILE_FILE"

# Permanently bind the dynamic ecosystem binaries into the native Mac terminal profiles
if ! grep -q "shellenv" "$PROFILE_FILE"; then
    echo "Injecting operational variables into $PROFILE_FILE..."
    if [ -f /opt/homebrew/bin/brew ]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$PROFILE_FILE"
    >> "$PROFILE_FILE"
    else
        echo 'eval "$(/usr/local/bin/brew shellenv)"' >> "$PROFILE_FILE"
    fi
fi

echo "=============================================================================="
echo " STAGE 7: PRODUCTION SUITE SYSTEM VERIFICATION"
echo "=============================================================================="
echo -e "\n--- VERIFYING MACOS TAHOE ENGINE STACK ---"
sw_vers
git --version
gh --version
python3 --version
node --version
uv --version
brew --version
omlx --version
npm list -g --depth=0
echo "------------------------------------------"

echo "Bootstrap complete! Launch Docker and Ollama from your Applications grid to finish setup."
echo "Execute 'source ~/.zshrc' to cleanly initialize all paths in your current terminal pane."
