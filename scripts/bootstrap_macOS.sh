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

BREW_PACKAGES=(
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
    coreutils
)

BREW_CASKS=(
    visual-studio-code
    iterm2
    github
    obsidian
    tailscale
    chatgpt
    bitwarden
    slack
    claude
)

AI_CLI_CHECKS=(
    "Claude Code:claude --version"
    "Codex CLI:codex --version"
    "GitHub Copilot CLI:copilot --version"
    "Google Antigravity CLI:agy --version"
    "Zed:zed --version"
    "GitHub CLI:gh --version"
    "Node.js:node --version"
    "npm:npm --version"
)

log() {
    echo "$*"
    echo "$*" >> "$BOOTSTRAP_LOG"
}

record_success() {
    SUCCESSES+=("$1")
    log "OK: $1"
}

warn() {
    WARNINGS+=("$1")
    log "WARN: $1"
}

print_stage() {
    local title="$1"
    echo "=============================================================================="
    echo " $title"
    echo "=============================================================================="
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

    warn "$description failed"
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

ensure_homebrew() {
    if command -v brew >/dev/null 2>&1; then
        record_success "Homebrew already installed"
    else
        run_step "Install Homebrew" bash -c 'NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    fi

    if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
        record_success "Loaded Homebrew environment from /opt/homebrew"
    elif [[ -x /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
        record_success "Loaded Homebrew environment from /usr/local"
    else
        warn "Unable to locate brew after installation"
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

install_optional_gemini_cask() {
    if [[ "$ARCH" == "arm64" && "$MACOS_MAJOR_VERSION" -ge 15 ]]; then
        if brew list --cask google-gemini >/dev/null 2>&1; then
            record_success "Homebrew cask already installed: google-gemini"
        else
            run_optional_step "Install Homebrew cask: google-gemini" brew install --cask google-gemini
        fi
    else
        warn "Skipping google-gemini cask; requires Apple Silicon and macOS 15+"
    fi
}

ensure_npm_global_path() {
    if ! command -v npm >/dev/null 2>&1; then
        warn "npm is not available; skipping npm global path setup"
        return 0
    fi

    mkdir -p "$HOME/.npm-global"
    record_success "Ensured npm global directory exists"
    run_step "Configure npm global prefix" npm config set prefix "$HOME/.npm-global"

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

    log "Installing $description..."
    if bash -c "$command" >> "$BOOTSTRAP_LOG" 2>&1; then
        hash -r
        record_success "Installed $description"
    else
        warn "Failed to install $description"
    fi
}

create_ll_wrapper() {
    if ! command -v gls >/dev/null 2>&1; then
        warn "gls not available; skipping ll wrapper creation"
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

log "=============================================================================="
log " MACOS AI DEV BOOTSTRAP"
log " Log file: $BOOTSTRAP_LOG"
log " Architecture: $ARCH"
log " macOS major version: $MACOS_MAJOR_VERSION"
log "=============================================================================="

print_stage "STAGE 1: HOMEBREW SETUP"
ensure_homebrew
run_optional_step "Update Homebrew" brew update

print_stage "STAGE 2: CORE CLI TOOLS"
install_brew_packages
ensure_npm_global_path
install_shell_cli "Claude Code" "npm install -g @anthropic-ai/claude-code"
install_shell_cli "Codex CLI" "curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_NON_INTERACTIVE=1 sh"
install_shell_cli "Google Antigravity CLI" "curl -fsSL https://antigravity.google/cli/install.sh | bash"
install_shell_cli "GitHub Copilot CLI" "curl -fsSL https://gh.io/copilot-install | bash"
install_shell_cli "Zed IDE" "curl -fsSL https://zed.dev/install.sh | sh"
run_optional_pipe_step "Install one-file-context" "npm install -g one-file-context"

print_stage "STAGE 3: GUI APPLICATIONS"
install_brew_casks
install_optional_gemini_cask

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
log ""
log "--- HOMEBREW PACKAGES ---"
verify_brew_apps
log "------------------------------------------------"
log "Bootstrap complete!"
log ""
run_optional_step "Run fastfetch" fastfetch

print_summary
