#!/usr/bin/env bash
# ==============================================================================
# UNATTENDED AI DEVELOPMENT ENVIRONMENT BOOTSTRAP - UBUNTU (APT / NO-SNAP)
# ==============================================================================
set -euo pipefail

BOOTSTRAP_LOG="${HOME}/bootstrap_ubuntu_$(date +%Y%m%d_%H%M%S).log"
WARNINGS=()
SUCCESSES=()
DESKTOP_ENV="${XDG_CURRENT_DESKTOP:-unknown}"
SKIP_FLATPAK_INSTALLS=0

BASE_PACKAGES=(
    apt-transport-https
    ca-certificates
    curl
    wget
    git
    gpg
    build-essential
    p7zip-full
    htop
    python3-pip
    fastfetch
    flatpak
    zstd
    lsb-release
)

OPTIONAL_PACKAGES=()

FLATPAK_APPS=(
    com.brave.Browser
    com.bitwarden.desktop
    md.obsidian.Obsidian
    com.slack.Slack
)

AI_CLI_CHECKS=(
    "Claude Code:claude --version"
    "Codex CLI:codex --version"
    "GitHub Copilot CLI:copilot --version"
    "Google Antigravity CLI:agy --version"
    "Ollama:ollama --version"
    "Zed:zed --version"
    "VS Code:code --version"
    "GitHub CLI:gh --version"
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

run_pipe_step() {
    local description="$1"
    local command="$2"
    if bash -c "$command" >> "$BOOTSTRAP_LOG" 2>&1; then
        record_success "$description"
        return 0
    fi

    warn "$description failed"
    return 1
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

configure_github_cli_repo() {
    log "Configuring GitHub CLI APT repository..."
    sudo mkdir -p /etc/apt/keyrings
    run_pipe_step "Install GitHub CLI keyring" "curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null"
    run_pipe_step "Write GitHub CLI sources list" "echo 'deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main' | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null"
}

configure_vscode_repo() {
    log "Configuring Visual Studio Code APT repository..."
    sudo rm -f /etc/apt/sources.list.d/vscode.list
    sudo rm -f /etc/apt/keyrings/packages.microsoft.gpg
    sudo rm -f /etc/apt/preferences.d/vscode

    sudo mkdir -p /etc/apt/keyrings
    run_pipe_step "Install VS Code keyring" "curl -fSsL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/keyrings/packages.microsoft.gpg > /dev/null"
    run_pipe_step "Write VS Code sources list" "cat <<'EOF' | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main
EOF"
    run_pipe_step "Write VS Code apt pin" "cat <<'EOF' | sudo tee /etc/apt/preferences.d/vscode > /dev/null
Package: code
Pin: origin packages.microsoft.com
Pin-Priority: 1001
EOF"
}

install_vscode() {
    if configure_vscode_repo; then
        run_step "APT update after adding VS Code repo" sudo apt-get update
        run_optional_step "Install Visual Studio Code" sudo apt-get install -y code
    else
        warn "Failed to configure Visual Studio Code repository"
    fi
}

install_github_cli() {
    if configure_github_cli_repo; then
        run_step "APT update after adding GitHub CLI repo" sudo apt-get update
        run_optional_step "Install GitHub CLI" sudo apt-get install -y gh
    else
        warn "Failed to configure GitHub CLI repository"
    fi
}

install_flatpaks() {
    local app

    if ! sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo >> "$BOOTSTRAP_LOG" 2>&1; then
        warn "Failed to add Flathub remote; skipping Flatpak app installs"
        SKIP_FLATPAK_INSTALLS=1
        return 0
    fi

    record_success "Configured Flathub remote"

    for app in "${FLATPAK_APPS[@]}"; do
        run_optional_step "Install Flatpak: $app" sudo flatpak install flathub "$app" -y
    done
}

get_desktop_packages() {
    case "$DESKTOP_ENV" in
        *KDE*|*Plasma*)
            printf '%s\n' plasma-discover-backend-flatpak kdeconnect konsole
            ;;
        *GNOME*)
            printf '%s\n' gnome-tweaks gnome-shell-extension-manager dconf-editor
            ;;
        *)
            warn "Unknown desktop environment '$DESKTOP_ENV'; skipping desktop-specific packages"
            ;;
    esac
}

install_desktop_packages() {
    local pkg
    while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue
        run_optional_step "Desktop package install: $pkg" sudo apt-get install -y "$pkg"
    done < <(get_desktop_packages)
}

install_ollama() {
    run_optional_pipe_step "Install Ollama" "curl -fsSL https://ollama.com/install.sh | sh"
    run_optional_step "Enable and start Ollama service" sudo systemctl enable --now ollama
}

ensure_npm_global_path() {
    if ! command -v npm >/dev/null 2>&1; then
        warn "npm is not available; skipping npm global path setup"
        return 0
    fi

    mkdir -p "$HOME/.npm-global"
    record_success "Ensured npm global directory exists"
    run_step "Configure npm global prefix" npm config set prefix "$HOME/.npm-global"

    if ! grep -Fqx 'export PATH="$HOME/.npm-global/bin:$PATH"' "$HOME/.bashrc"; then
        echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> "$HOME/.bashrc"
        record_success "Added npm global bin PATH to ~/.bashrc"
    else
        record_success "npm global bin PATH already present in ~/.bashrc"
    fi

    export PATH="$HOME/.npm-global/bin:$PATH"
    hash -r
    record_success "Exported npm global bin PATH in current shell"
}

install_nodejs() {
    run_optional_pipe_step "Configure NodeSource LTS repository" "curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -"
    run_optional_step "Install Node.js" sudo apt-get install -y nodejs
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

verify_ai_clis() {
    local entry description command
    for entry in "${AI_CLI_CHECKS[@]}"; do
        description="${entry%%:*}"
        command="${entry#*:}"
        run_optional_pipe_step "Check $description version" "$command"
    done
}

verify_flatpaks() {
    local app
    local missing=0

    if [[ "$SKIP_FLATPAK_INSTALLS" -eq 1 ]]; then
        warn "Skipping Flatpak verification because Flathub setup failed"
        return 0
    fi

    for app in "${FLATPAK_APPS[@]}"; do
        if flatpak list --app --columns=application | grep -Fxq "$app"; then
            record_success "Verified Flatpak: $app"
        else
            warn "Missing expected Flatpak: $app"
            missing=1
        fi
    done

    return "$missing"
}

check_snap_state() {
    if command -v snap >/dev/null 2>&1; then
        warn "snap command is present on the system; this bootstrap does not install snap packages"
    else
        record_success "snap command not present"
    fi
}

print_summary() {
    echo ""
    echo "=============================================================================="
    echo " FINAL SUMMARY"
    echo "=============================================================================="
    echo "Log file: $BOOTSTRAP_LOG"
    echo "Detected desktop: $DESKTOP_ENV"
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
log " UBUNTU AI DEV BOOTSTRAP (NO-SNAP)"
log " Log file: $BOOTSTRAP_LOG"
log " Detected desktop: $DESKTOP_ENV"
log "=============================================================================="

print_stage "STAGE 1: SYSTEM UPDATES & OPTIMIZATIONS"
sudo tee /etc/apt/apt.conf.d/99parallel-downloads << 'EOF' >> "$BOOTSTRAP_LOG"
APT::Periodic::Enable "0";
Binary::apt::APT::Keep-Downloaded-Packages "true";
EOF
record_success "Configured APT download settings"
run_step "APT update" sudo apt-get update
run_step "APT dist-upgrade" sudo apt-get dist-upgrade -y
run_step "Base package install" sudo apt-get install -y "${BASE_PACKAGES[@]}"
run_optional_step "Optional APT package batch skipped cleanly" true
run_optional_step "Git config core.fscache" git config --global core.fscache true
run_optional_step "Git config core.preloadindex" git config --global core.preloadindex true
run_optional_step "Git config gc.auto" git config --global gc.auto 256

print_stage "STAGE 2: APPLICATION RUNTIMES & REPOSITORIES"
install_github_cli
install_vscode
install_flatpaks
install_desktop_packages
check_snap_state

print_stage "STAGE 3: LOCAL AI ENGINE DEPLOYMENT (OLLAMA)"
install_ollama

print_stage "STAGE 4: CLOUD AI CLI TOOLING"
install_nodejs
ensure_npm_global_path
install_shell_cli "Claude Code" "npm install -g @anthropic-ai/claude-code"
install_shell_cli "Codex CLI" "npm install -g @openai/codex"
install_shell_cli "Google Antigravity CLI" "curl -fsSL https://antigravity.google/cli/install.sh | bash"
install_shell_cli "GitHub Copilot CLI" "curl -fsSL https://gh.io/copilot-install | bash"
install_shell_cli "Zed IDE" "curl -fsSL https://zed.dev/install.sh | sh"
run_optional_pipe_step "Install one-file-context" "npm install -g one-file-context"

print_stage "STAGE 5: SYSTEM PRODUCTION VERIFICATION"
log "--- VERIFYING UBUNTU WORKSTATION ENGINE STACK ---"
run_optional_step "Read Ubuntu release" lsb_release -d
run_optional_step "Check git version" git --version
run_optional_pipe_step "Check gh version" "gh --version"
run_optional_pipe_step "Check node version" "node --version"
run_optional_pipe_step "Check npm version" "npm --version"
log ""
log "--- NPM GLOBALS ---"
run_optional_pipe_step "List global npm packages" "npm list -g --depth=0"
log ""
log "--- AI TOOLING ---"
verify_ai_clis
log ""
log "--- FLATPAKS ---"
verify_flatpaks || true
log "------------------------------------------------"
log "Bootstrap complete!"
log ""
run_optional_step "Run fastfetch" fastfetch

print_summary
