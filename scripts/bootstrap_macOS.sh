#!/usr/bin/env bash
# ==============================================================================
# UNATTENDED AI DEVELOPMENT ENVIRONMENT BOOTSTRAP - MACOS (HOMEBREW)
# Designed to be run remotely via:
# bash <(curl -fsSL https://raw.githubusercontent.com/bensonlabs/bootstraps/main/scripts/bootstrap_macOS.sh)
# ==============================================================================
set -euo pipefail

BOOTSTRAP_LOG="${HOME}/bootstrap_macos_$(date +%Y%m%d_%H%M%S).log"
WARNINGS=()
SUCCESSES=()
ARCH="$(uname -m)"
MACOS_MAJOR_VERSION="$(sw_vers -productVersion | cut -d. -f1)"
FATAL_ERROR=0
BREW_PKG_URL="https://github.com/Homebrew/brew/releases/latest/download/Homebrew.pkg"
BREW_PKG_PATH="/tmp/Homebrew.pkg"

BREW_PACKAGES=(
    git
    gh
    node
    python
    ripgrep
    bat
    tree
    htop
    starship
    fish
    zsh-completions
    coreutils
    fastfetch
    sevenzip
)

BREW_CASKS=(
    visual-studio-code
    obsidian
    chatgpt
    bitwarden
    slack
    claude
    zed
)

AI_CLI_CHECKS=(
    "Claude Code:claude --version"
    "Codex CLI:codex --version"
    "GitHub CLI:gh --version"
    "Node.js:node --version"
    "npm:npm --version"
    "Python:python3 --version"
    "pip:pip3 --version"
    "ripgrep:rg --version"
    "fastfetch:fastfetch --version"
    "7zip:7zz"
)

log() {
    echo "$*" | tee -a "$BOOTSTRAP_LOG"
}

record_success() {
    SUCCESSES+=("$1")
    log "OK: $1"
}

warn() {
    WARNINGS+=("$1")
    log "WARN: $1"
}

fatal() {
    FATAL_ERROR=1
    WARNINGS+=("FATAL: $1")
    log "FATAL: $1"
}

print_stage() {
    local title="$1"
    log "=============================================================================="
    log " $title"
    log "=============================================================================="
}

run_step() {
    local description="$1"
    shift
    if "$@" >> "$BOOTSTRAP_LOG" 2>&1; then
        record_success "$description"
        return 0
    fi

    fatal "$description failed"
    return 1
}

run_optional_step() {
    local description="$1"
    shift
    if "$@" >> "$BOOTSTRAP_LOG" 2>&1; then
        record_success "$description"
    else
        warn "$description failed; continuing"
    fi
}

run_optional_pipe_step() {
    local description="$1"
    local command="$2"
    if bash -c "$command" >> "$BOOTSTRAP_LOG" 2>&1; then
        record_success "$description"
    else
        warn "$description failed; continuing"
    fi
}

ensure_sudo_session() {
    log "Requesting sudo access for system-level install steps..."
    if sudo -v >> "$BOOTSTRAP_LOG" 2>&1; then
        record_success "Cached sudo credentials"
    else
        fatal "Unable to obtain sudo credentials"
        return 1
    fi
}

ensure_xcode_clt() {
    if xcode-select -p >/dev/null 2>&1; then
        record_success "Xcode Command Line Tools already configured"
        return 0
    fi

    warn "Xcode Command Line Tools are required before Homebrew can install"
    log "Launching 'xcode-select --install'... you will need to click Install in the macOS dialog, then rerun this script after installation completes."
    if xcode-select --install >> "$BOOTSTRAP_LOG" 2>&1; then
        record_success "Triggered Xcode Command Line Tools installer"
    else
        warn "xcode-select --install did not complete successfully; it may already be in progress"
    fi

    fatal "Xcode Command Line Tools must be installed manually before continuing"
    return 1
}

check_brew_health() {
    log "Running Homebrew health preflight..."

    if command -v brew >/dev/null 2>&1; then
        if ! brew doctor >> "$BOOTSTRAP_LOG" 2>&1; then
            warn "brew doctor reported issues; continuing because Homebrew may still be usable"
        else
            record_success "Homebrew health preflight passed"
        fi
    else
        record_success "Homebrew not yet installed; skipping brew doctor preflight"
    fi
}

ensure_homebrew() {
    if command -v brew >/dev/null 2>&1; then
        record_success "Homebrew already installed"
    else
        log "Installing Homebrew silently via macOS pkg installer..."
        run_step "Download Homebrew pkg installer" curl -fsSL -o "$BREW_PKG_PATH" "$BREW_PKG_URL" || return 1
        run_step "Install Homebrew pkg" sudo installer -pkg "$BREW_PKG_PATH" -target / || return 1
        run_optional_step "Remove Homebrew pkg installer" rm -f "$BREW_PKG_PATH"
        record_success "Installed Homebrew via pkg"
    fi

    if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
        record_success "Loaded Homebrew environment from /opt/homebrew"
    elif [[ -x /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
        record_success "Loaded Homebrew environment from /usr/local"
    else
        fatal "Unable to locate brew after installation"
        return 1
    fi
}

install_brew_packages() {
    local pkg
    for pkg in "${BREW_PACKAGES[@]}"; do
        if brew list "$pkg" >/dev/null 2>&1; then
            record_success "Homebrew package already installed: $pkg"
        else
            run_optional_step "Install Homebrew package: $pkg" brew install "$pkg"
        fi
    done
}

install_brew_casks() {
    local cask
    for cask in "${BREW_CASKS[@]}"; do
        if brew list --cask "$cask" >/dev/null 2>&1; then
            record_success "Homebrew cask already installed: $cask"
        else
            run_optional_step "Install Homebrew cask: $cask" brew install --cask "$cask"
        fi
    done
}

ensure_npm_global_path() {
    if ! command -v npm >/dev/null 2>&1; then
        warn "npm is not available; skipping npm global path setup"
        return 0
    fi

    mkdir -p "$HOME/.npm-global"
    record_success "Ensured npm global directory exists"
    run_step "Configure npm global prefix" npm config set prefix "$HOME/.npm-global" || return 1

    if ! grep -Fqx 'export PATH="$HOME/.npm-global/bin:$PATH"' "$HOME/.zshrc" 2>/dev/null; then
        echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> "$HOME/.zshrc"
        record_success "Added npm global bin PATH to ~/.zshrc"
    else
        record_success "npm global bin PATH already present in ~/.zshrc"
    fi

    export PATH="$HOME/.npm-global/bin:$PATH"
    hash -r
    record_success "Exported npm global bin PATH in current shell"
}

install_shell_cli() {
    local description="$1"
    local command="$2"
    local binary="$3"

    if command -v "$binary" >/dev/null 2>&1; then
        record_success "$description already installed"
        return 0
    fi

    log "Installing $description..."
    if bash -c "$command" >> "$BOOTSTRAP_LOG" 2>&1; then
        hash -r
        record_success "Installed $description"
    else
        warn "Failed to install $description"
    fi
}

verify_github_copilot_cli() {
    if command -v copilot >/dev/null 2>&1; then
        record_success "Verified GitHub Copilot CLI command is present"
    else
        warn "GitHub Copilot CLI command not found in PATH; continuing"
    fi
}

verify_agy_cli() {
    if command -v agy >/dev/null 2>&1; then
        record_success "Verified Google Antigravity CLI command is present"
    else
        warn "Google Antigravity CLI command not found in PATH; continuing"
    fi
}

create_ll_wrapper() {
    if ! command -v gls >/dev/null 2>&1; then
        warn "gls not available; skipping ll wrapper creation"
        return 0
    fi

    if [[ -x /usr/local/bin/ll ]] && grep -Fq 'exec gls -laFo --color=auto --group-directories-first "$@"' /usr/local/bin/ll 2>/dev/null; then
        record_success "ll wrapper already configured"
        return 0
    fi

    run_optional_step "Ensure /usr/local/bin exists" sudo mkdir -p /usr/local/bin
    if sudo tee /usr/local/bin/ll > /dev/null << 'EOF'
#!/bin/sh
exec gls -laFo --color=auto --group-directories-first "$@"
EOF
    then
        record_success "Created ll wrapper"
    else
        warn "Failed to create ll wrapper"
        return 0
    fi

    run_optional_step "Make ll wrapper executable" sudo chmod +x /usr/local/bin/ll
}

configure_macos_defaults() {
    run_optional_step "Expand save panel by default" defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
    run_optional_step "Expand save panel by default (v2)" defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
    run_optional_step "Show hidden files in Finder" defaults write com.apple.finder AppleShowAllFiles -bool true
    run_optional_step "Show Finder path bar" defaults write com.apple.finder ShowPathbar -bool true
    run_optional_step "Speed up window resize animations" defaults write NSGlobalDomain NSWindowResizeTime -float 0.001
    run_optional_step "Restart Finder" killall Finder
}

verify_brew_apps() {
    local pkg
    for pkg in "${BREW_PACKAGES[@]}"; do
        if brew list "$pkg" >/dev/null 2>&1; then
            record_success "Verified Homebrew package: $pkg"
        else
            warn "Missing expected Homebrew package: $pkg"
        fi
    done

    local cask
    for cask in "${BREW_CASKS[@]}"; do
        if brew list --cask "$cask" >/dev/null 2>&1; then
            record_success "Verified Homebrew cask: $cask"
        else
            warn "Missing expected Homebrew cask: $cask"
        fi
    done
}

verify_ai_clis() {
    local entry description command
    for entry in "${AI_CLI_CHECKS[@]}"; do
        description="${entry%%:*}"
        command="${entry#*:}"
        run_optional_pipe_step "Check $description version" "$command"
    done
}

print_summary() {
    echo ""
    echo "=============================================================================="
    echo " FINAL SUMMARY"
    echo "=============================================================================="
    echo "Log file: $BOOTSTRAP_LOG"
    echo "Architecture: $ARCH"
    echo "macOS major version: $MACOS_MAJOR_VERSION"
    echo "Successful steps: ${#SUCCESSES[@]}"
    echo "Warnings: ${#WARNINGS[@]}"
    echo "Fatal error state: $FATAL_ERROR"

    echo ""
    echo "Successful items:"
    for item in "${SUCCESSES[@]}"; do
        echo "  - $item"
    done

    if [[ ${#WARNINGS[@]} -gt 0 ]]; then
        echo ""
        echo "Warnings encountered:"
        for item in "${WARNINGS[@]}"; do
            echo "  - $item"
        done
        echo ""
        echo "Review the full log at: $BOOTSTRAP_LOG"
    else
        echo ""
        echo "No warnings encountered."
    fi
}

finish() {
    print_summary
    if [[ "$FATAL_ERROR" -ne 0 ]]; then
        exit 1
    fi
}

trap finish EXIT

log "=============================================================================="
log " MACOS AI DEV BOOTSTRAP"
log " Log file: $BOOTSTRAP_LOG"
log " Architecture: $ARCH"
log " macOS major version: $MACOS_MAJOR_VERSION"
log "=============================================================================="

print_stage "STAGE 0: PACKAGE MANAGER PREFLIGHT"
ensure_sudo_session || exit 1
ensure_xcode_clt || exit 1
ensure_homebrew || exit 1
check_brew_health

print_stage "STAGE 1: HOMEBREW SETUP"
run_optional_step "Update Homebrew" brew update

print_stage "STAGE 2: CORE CLI TOOLS"
install_brew_packages
ensure_npm_global_path || exit 1
install_shell_cli "Claude Code" "npm install -g @anthropic-ai/claude-code" claude
install_shell_cli "Codex CLI" "npm install -g @openai/codex" codex
install_shell_cli "Google Antigravity CLI" "curl -fsSL https://antigravity.google/cli/install.sh | bash" agy
install_shell_cli "GitHub Copilot CLI" "PREFIX=$HOME/.npm-global bash -c 'curl -fsSL https://gh.io/copilot-install | bash'" copilot

print_stage "STAGE 3: GUI APPLICATIONS"
install_brew_casks

print_stage "STAGE 4: SYSTEM CUSTOMIZATION"
create_ll_wrapper
configure_macos_defaults

print_stage "STAGE 5: SYSTEM PRODUCTION VERIFICATION"
run_optional_step "Check Homebrew version" brew --version
run_optional_step "Check git version" git --version
log ""
log "--- NPM GLOBALS ---"
run_optional_pipe_step "List global npm packages" "npm list -g --depth=0"
log ""
log "--- AI TOOLING ---"
verify_ai_clis
verify_github_copilot_cli
verify_agy_cli
log ""
log "--- HOMEBREW PACKAGES ---"
verify_brew_apps
log "------------------------------------------------"
log "Bootstrap complete!"
log ""
run_optional_step "Run fastfetch" fastfetch
