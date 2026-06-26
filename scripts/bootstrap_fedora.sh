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

FLATPAK_APPS=(
    com.visualstudio.code
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
    "Zed:zed --version"
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

run_optional_pipe_step() {
    local description="$1"
    local command="$2"
    if bash -c "$command" >> "$BOOTSTRAP_LOG" 2>&1; then
        record_success "$description"
    else
        warn "$description failed; continuing"
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
        run_optional_step "Desktop package install: $pkg" sudo dnf5 install -y "$pkg"
    done < <(get_desktop_packages)
}

install_tailscale() {
    run_optional_step "Install tailscale" sudo dnf5 install -y tailscale
    run_optional_step "Enable and start tailscaled" sudo systemctl enable --now tailscaled
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
log " FEDORA AI DEV BOOTSTRAP"
log " Log file: $BOOTSTRAP_LOG"
log " Detected desktop: $DESKTOP_ENV"
log "=============================================================================="

print_stage "STAGE 1: SYSTEM UPDATES & OPTIMIZATIONS"
sudo tee /etc/dnf/dnf.conf << 'EOF' >> "$BOOTSTRAP_LOG"
[main]
fastestmirror=True
max_parallel_downloads=10
defaultyes=True
EOF
record_success "Configured /etc/dnf/dnf.conf"

run_step "System upgrade" sudo dnf5 upgrade -y
run_step "Development Tools group install" sudo dnf5 group install development-tools -y
run_step "Base package install" sudo dnf5 install -y "${BASE_PACKAGES[@]}"
run_optional_step "Git config core.fscache" git config --global core.fscache true
run_optional_step "Git config core.preloadindex" git config --global core.preloadindex true
run_optional_step "Git config gc.auto" git config --global gc.auto 256

print_stage "STAGE 2: APPLICATION RUNTIMES & REPOSITORIES"
install_flatpaks
install_desktop_packages
install_tailscale

print_stage "STAGE 3: LOCAL AI ENGINE (OLLAMA) - SKIPPED"
# Uncomment to enable Ollama
# curl -fsSL https://ollama.com/install.sh | sh
# sudo systemctl enable --now ollama

print_stage "STAGE 4: CLOUD AI CLI TOOLING"
ensure_npm_global_path
install_shell_cli "Claude Code" "npm install -g @anthropic-ai/claude-code"
install_shell_cli "Codex CLI" "curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_NON_INTERACTIVE=1 sh"
install_shell_cli "Zed IDE" "curl -fsSL https://zed.dev/install.sh | sh"
install_shell_cli "Google Antigravity CLI" "curl -fsSL https://antigravity.google/cli/install.sh | bash"
install_shell_cli "GitHub Copilot CLI" "curl -fsSL https://gh.io/copilot-install | bash"

print_stage "STAGE 5: SYSTEM PRODUCTION VERIFICATION"
log "--- VERIFYING FEDORA WORKSTATION ENGINE STACK ---"
run_optional_step "Read Fedora release" cat /etc/fedora-release
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
log "--- SYSTEM SERVICES ---"
run_optional_step "Check Tailscale version" tailscale version
log ""
log "--- FLATPAKS ---"
verify_flatpaks
log "------------------------------------------------"
log "Bootstrap complete!"
log ""
run_optional_step "Run fastfetch" fastfetch

print_summary
