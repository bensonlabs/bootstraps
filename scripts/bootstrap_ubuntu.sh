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
FATAL_ERROR=0

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
    python3
    python3-pip
    fastfetch
    flatpak
    zstd
    lsb-release
    ripgrep
)

FLATPAK_APPS=(
    com.visualstudio.code
    com.brave.Browser
    com.bitwarden.desktop
    md.obsidian.Obsidian
    com.slack.Slack
    com.openai.chatgpt
    com.anthropic.claude
)

AI_CLI_CHECKS=(
    "Claude Code:claude --version"
    "Codex CLI:codex --version"
    "GitHub Copilot CLI:copilot --version"
    "Google Antigravity CLI:agy --version"
    "one-file-context:one-file-context --help"
    "Zed:zed --version"
    "VS Code:code --version"
    "GitHub CLI:gh --version"
    "Node.js:node --version"
    "npm:npm --version"
    "Python:python3 --version"
    "pip:pip3 --version"
    "ripgrep:rg --version"
    "fastfetch:fastfetch --version"
    "7zip:7z"
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

run_pipe_step() {
    local description="$1"
    local command="$2"
    if bash -c "$command" >> "$BOOTSTRAP_LOG" 2>&1; then
        record_success "$description"
        return 0
    fi

    fatal "$description failed"
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

check_apt_health() {
    log "Running APT health preflight..."

    if ! sudo apt-get update >> "$BOOTSTRAP_LOG" 2>&1; then
        fatal "APT update failed during preflight"
        return 1
    fi

    if ! sudo apt-get check >> "$BOOTSTRAP_LOG" 2>&1; then
        fatal "APT health check failed; package state appears inconsistent. Restore a clean snapshot or repair the system before re-running."
        return 1
    fi

    record_success "APT health preflight passed"
}

configure_github_cli_repo() {
    if [[ -f /etc/apt/sources.list.d/github-cli.list ]]; then
        record_success "GitHub CLI APT source already present"
    else
        log "Configuring GitHub CLI APT repository..."
        sudo mkdir -p /etc/apt/keyrings
        run_pipe_step "Install GitHub CLI keyring" "curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null" || return 1
        run_pipe_step "Write GitHub CLI sources list" "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main\" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null" || return 1
    fi
}

configure_vscode_repo() {
    if [[ -f /etc/apt/sources.list.d/vscode.list && -f /etc/apt/keyrings/packages.microsoft.gpg ]]; then
        record_success "Visual Studio Code APT source already present"
        return 0
    fi

    log "Configuring Visual Studio Code APT repository..."
    sudo rm -f /etc/apt/sources.list.d/vscode.list
    sudo rm -f /etc/apt/keyrings/packages.microsoft.gpg
    sudo rm -f /etc/apt/preferences.d/vscode

    sudo mkdir -p /etc/apt/keyrings
    run_pipe_step "Install VS Code keyring" "curl -fSsL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/keyrings/packages.microsoft.gpg > /dev/null" || return 1
    run_pipe_step "Write VS Code sources list" "cat <<'EOF' | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main
EOF" || return 1
    run_pipe_step "Write VS Code apt pin" "cat <<'EOF' | sudo tee /etc/apt/preferences.d/vscode > /dev/null
Package: code
Pin: origin packages.microsoft.com
Pin-Priority: 1001
EOF" || return 1
}

install_vscode() {
    configure_vscode_repo || return 1
    run_step "APT update after adding VS Code repo" sudo apt-get update || return 1
    if command -v code >/dev/null 2>&1; then
        record_success "Visual Studio Code already installed"
    else
        run_optional_step "Install Visual Studio Code" sudo apt-get install -y code
    fi
}

install_github_cli() {
    configure_github_cli_repo || return 1
    run_step "APT update after adding GitHub CLI repo" sudo apt-get update || return 1
    if command -v gh >/dev/null 2>&1; then
        record_success "GitHub CLI already installed"
    else
        run_optional_step "Install GitHub CLI" sudo apt-get install -y gh
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
        if flatpak list --app --columns=application | grep -Fxq "$app"; then
            record_success "Flatpak already installed: $app"
        else
            run_optional_step "Install Flatpak: $app" sudo flatpak install flathub "$app" -y
        fi
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
        if dpkg -s "$pkg" >> "$BOOTSTRAP_LOG" 2>&1; then
            record_success "Desktop package already installed: $pkg"
        else
            run_optional_step "Desktop package install: $pkg" sudo apt-get install -y "$pkg"
        fi
    done < <(get_desktop_packages)
}

ensure_npm_global_path() {
    if ! command -v npm >/dev/null 2>&1; then
        warn "npm is not available; skipping npm global path setup"
        return 0
    fi

    mkdir -p "$HOME/.npm-global"
    record_success "Ensured npm global directory exists"
    run_step "Configure npm global prefix" npm config set prefix "$HOME/.npm-global" || return 1

    if ! grep -Fqx 'export PATH="$HOME/.npm-global/bin:$PATH"' "$HOME/.bashrc" 2>/dev/null; then
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
    if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
        record_success "Node.js and npm already installed"
        return 0
    fi

    run_optional_pipe_step "Configure NodeSource LTS repository" "curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -"
    run_optional_step "Install Node.js" sudo apt-get install -y nodejs
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

    if [[ "$SKIP_FLATPAK_INSTALLS" -eq 1 ]]; then
        warn "Skipping Flatpak verification because Flathub setup failed"
        return 0
    fi

    for app in "${FLATPAK_APPS[@]}"; do
        if flatpak list --app --columns=application | grep -Fxq "$app"; then
            record_success "Verified Flatpak: $app"
        else
            warn "Missing expected Flatpak: $app"
        fi
    done
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
log " UBUNTU AI DEV BOOTSTRAP (NO-SNAP)"
log " Log file: $BOOTSTRAP_LOG"
log " Detected desktop: $DESKTOP_ENV"
log "=============================================================================="

print_stage "STAGE 0: PACKAGE MANAGER PREFLIGHT"
check_apt_health || exit 1

print_stage "STAGE 1: SYSTEM UPDATES & OPTIMIZATIONS"
sudo tee /etc/apt/apt.conf.d/99parallel-downloads << 'EOF' >> "$BOOTSTRAP_LOG"
APT::Periodic::Enable "0";
Binary::apt::APT::Keep-Downloaded-Packages "true";
EOF
record_success "Configured APT download settings"
run_step "APT dist-upgrade" sudo apt-get dist-upgrade -y || exit 1
run_step "Base package install" sudo apt-get install -y "${BASE_PACKAGES[@]}" || exit 1
run_optional_step "Git config core.fscache" git config --global core.fscache true
run_optional_step "Git config core.preloadindex" git config --global core.preloadindex true
run_optional_step "Git config gc.auto" git config --global gc.auto 256

print_stage "STAGE 2: APPLICATION RUNTIMES & REPOSITORIES"
install_github_cli || exit 1
install_vscode || exit 1
install_flatpaks
install_desktop_packages
check_snap_state

print_stage "STAGE 3: CLOUD AI CLI TOOLING"
install_nodejs
ensure_npm_global_path || exit 1
install_shell_cli "Claude Code" "npm install -g @anthropic-ai/claude-code" claude
install_shell_cli "Codex CLI" "npm install -g @openai/codex" codex
install_shell_cli "Google Antigravity CLI" "curl -fsSL https://antigravity.google/cli/install.sh | bash" agy
install_shell_cli "GitHub Copilot CLI" "curl -fsSL https://gh.io/copilot-install | bash" copilot
install_shell_cli "Zed IDE" "curl -fsSL https://zed.dev/install.sh | sh" zed
install_shell_cli "one-file-context" "npm install -g one-file-context" one-file-context

print_stage "STAGE 4: SYSTEM PRODUCTION VERIFICATION"
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
verify_flatpaks
log "------------------------------------------------"
log "Bootstrap complete!"
log ""
run_optional_step "Run fastfetch" fastfetch
