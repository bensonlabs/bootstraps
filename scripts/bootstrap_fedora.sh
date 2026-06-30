#!/usr/bin/env bash
# ==============================================================================
# UNATTENDED AI DEVELOPMENT ENVIRONMENT BOOTSTRAP - FEDORA (DNF5)
# ==============================================================================
set -euo pipefail

BOOTSTRAP_LOG="${HOME}/bootstrap_fedora_$(date +%Y%m%d_%H%M%S).log"
WARNINGS=()
SUCCESSES=()
DESKTOP_ENV="${XDG_CURRENT_DESKTOP:-unknown}"
SKIP_FLATPAK_INSTALLS=0
FATAL_ERROR=0

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
    python3
    python3-pip
    fastfetch
    btrfs-progs
    snapper
    btrfs-assistant
    tree
    ripgrep
    flatpak
)

FLATPAK_APPS=(
    com.visualstudio.code
    com.brave.Browser
    com.bitwarden.desktop
    md.obsidian.Obsidian
    com.slack.Slack
    com.openai.chatgpt
    com.anthropic.claude
    dev.zed.Zed
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

check_dnf_health() {
    log "Running DNF health preflight..."

    if ! sudo dnf5 check >> "$BOOTSTRAP_LOG" 2>&1; then
        fatal "DNF health check failed; package state appears inconsistent. Restore a clean snapshot or repair the system before re-running."
        return 1
    fi

    record_success "DNF health preflight passed"
}

install_flatpaks() {
    local app

    if ! command -v flatpak >/dev/null 2>&1; then
        warn "flatpak is not available; skipping Flatpak app installs"
        SKIP_FLATPAK_INSTALLS=1
        return 0
    fi

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
            printf '%s\n' plasma-discover-flatpak kde-connect konsole
            ;;
        *GNOME*)
            printf '%s\n' gnome-tweaks gnome-extensions-app dconf-editor
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
        if rpm -q "$pkg" >> "$BOOTSTRAP_LOG" 2>&1; then
            record_success "Desktop package already installed: $pkg"
        else
            run_optional_step "Desktop package install: $pkg" sudo dnf5 install -y "$pkg"
        fi
    done < <(get_desktop_packages)
}

install_tailscale() {
    if rpm -q tailscale >> "$BOOTSTRAP_LOG" 2>&1; then
        record_success "tailscale already installed"
    else
        run_optional_step "Install tailscale" sudo dnf5 install -y tailscale
    fi

    if systemctl is-enabled tailscaled >> "$BOOTSTRAP_LOG" 2>&1 && systemctl is-active tailscaled >> "$BOOTSTRAP_LOG" 2>&1; then
        record_success "tailscaled already enabled and running"
    else
        run_optional_step "Enable and start tailscaled" sudo systemctl enable --now tailscaled
    fi
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
        warn "Skipping Flatpak verification because Flatpak setup failed"
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
log " FEDORA AI DEV BOOTSTRAP"
log " Log file: $BOOTSTRAP_LOG"
log " Detected desktop: $DESKTOP_ENV"
log "=============================================================================="

print_stage "STAGE 0: PACKAGE MANAGER PREFLIGHT"
ensure_sudo_session || exit 1
check_dnf_health || exit 1

print_stage "STAGE 1: SYSTEM UPDATES & OPTIMIZATIONS"
sudo tee /etc/dnf/dnf.conf << 'EOF' >> "$BOOTSTRAP_LOG"
[main]
fastestmirror=True
max_parallel_downloads=10
defaultyes=True
EOF
record_success "Configured /etc/dnf/dnf.conf"

run_step "System upgrade" sudo dnf5 upgrade -y || exit 1
run_step "Development Tools group install" sudo dnf5 group install -y "Development Tools" || exit 1
run_step "Base package install" sudo dnf5 install -y "${BASE_PACKAGES[@]}" || exit 1
run_optional_step "Git config core.fscache" git config --global core.fscache true
run_optional_step "Git config core.preloadindex" git config --global core.preloadindex true
run_optional_step "Git config gc.auto" git config --global gc.auto 256

print_stage "STAGE 2: APPLICATION RUNTIMES & REPOSITORIES"
install_flatpaks
install_desktop_packages
install_tailscale

print_stage "STAGE 3: CLOUD AI CLI TOOLING"
ensure_npm_global_path || exit 1
install_shell_cli "Claude Code" "npm install -g @anthropic-ai/claude-code" claude
install_shell_cli "Codex CLI" "npm install -g @openai/codex" codex
install_shell_cli "Google Antigravity CLI" "curl -fsSL https://antigravity.google/cli/install.sh | bash" agy
install_shell_cli "GitHub Copilot CLI" "PREFIX=$HOME/.npm-global bash -c 'curl -fsSL https://gh.io/copilot-install | bash'" copilot

print_stage "STAGE 4: SYSTEM PRODUCTION VERIFICATION"
log "--- VERIFYING FEDORA WORKSTATION ENGINE STACK ---"
run_optional_step "Read Fedora release" cat /etc/fedora-release
run_optional_pipe_step "Check gh version" "gh --version"
run_optional_pipe_step "Check node version" "node --version"
run_optional_pipe_step "Check npm version" "npm --version"
log ""
log "--- NPM GLOBALS ---"
run_optional_pipe_step "List global npm packages" "npm list -g --depth=0"
log ""
log "--- AI TOOLING ---"
verify_ai_clis
verify_github_copilot_cli
verify_agy_cli
log ""
log "--- SYSTEM SERVICES ---"
run_optional_step "Check Tailscale version" tailscale version
log ""
log "--- FLATPAKS ---"
verify_flatpaks
log "------------------------------------------------"
log "Bootstrap complete!"
log ""
run_optional_step "Run fastfetch" fastfetch
