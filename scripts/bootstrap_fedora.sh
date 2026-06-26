#!/usr/bin/env bash
# ==============================================================================
# UNATTENDED AI DEVELOPMENT ENVIRONMENT BOOTSTRAP - FEDORA (DNF5)
# ==============================================================================
set -euo pipefail

BOOTSTRAP_LOG="${HOME}/bootstrap_fedora_$(date +%Y%m%d_%H%M%S).log"
WARNINGS=()
SUCCESSES=()
SKIP_FLATPAK_INSTALLS=0
DESKTOP_ENV="${XDG_CURRENT_DESKTOP:-unknown}"

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

run_step() {
    local description="$1"
    shift
    if "$@"; then
        record_success "$description"
        return 0
    else
        warn "$description failed"
        return 1
    fi
}

run_optional_step() {
    local description="$1"
    shift
    if "$@"; then
        record_success "$description"
    else
        warn "$description failed; continuing"
    fi
}

log "=============================================================================="
log " FEDORA AI DEV BOOTSTRAP"
log " Log file: $BOOTSTRAP_LOG"
log " Detected desktop: $DESKTOP_ENV"
log "=============================================================================="

echo "=============================================================================="
echo " STAGE 1: SYSTEM UPDATES & OPTIMIZATIONS"
echo "=============================================================================="
sudo tee /etc/dnf/dnf.conf << 'EOF'
[main]
fastestmirror=True
max_parallel_downloads=10
defaultyes=True
EOF
record_success "Configured /etc/dnf/dnf.conf"

run_step "System upgrade" sudo dnf5 upgrade -y
run_step "Development Tools group install" sudo dnf5 group install development-tools -y

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

run_step "Base package install" sudo dnf5 install -y "${BASE_PACKAGES[@]}"

for pkg in "${OPTIONAL_PACKAGES[@]}"; do
    run_optional_step "Optional package install: $pkg" sudo dnf5 install -y "$pkg"
done

run_optional_step "Git config core.fscache" git config --global core.fscache true
run_optional_step "Git config core.preloadindex" git config --global core.preloadindex true
run_optional_step "Git config gc.auto" git config --global gc.auto 256

echo "=============================================================================="
echo " STAGE 2: APPLICATION RUNTIMES & REPOSITORIES"
echo "=============================================================================="
if sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo; then
    record_success "Configured Flathub remote"
else
    warn "Failed to add Flathub remote; skipping Flatpak app installs"
    SKIP_FLATPAK_INSTALLS=1
fi

if [[ "$SKIP_FLATPAK_INSTALLS" -eq 0 ]]; then
    run_optional_step "Install Visual Studio Code Flatpak" sudo flatpak install flathub com.visualstudio.code -y
fi

echo "=============================================================================="
echo " STAGE 2B: DEVELOPER & PRODUCTIVITY APPLICATIONS"
echo "=============================================================================="
FLATPAK_APPS=(
    "com.brave.Browser"
    "com.bitwarden.desktop"
    "md.obsidian.Obsidian"
    "com.slack.Slack"
)

if [[ "$SKIP_FLATPAK_INSTALLS" -eq 0 ]]; then
    log "Installing productivity flatpaks..."
    for app in "${FLATPAK_APPS[@]}"; do
        run_optional_step "Install Flatpak: $app" sudo flatpak install flathub "$app" -y
    done
else
    warn "Skipping productivity flatpaks because Flathub could not be configured"
fi

DESKTOP_PACKAGES=()
case "$DESKTOP_ENV" in
    *KDE*|*Plasma*)
        DESKTOP_PACKAGES=(
            plasma-discover-flatpak
            kde-connect
            konsole
        )
        ;;
    *GNOME*)
        DESKTOP_PACKAGES=(
            gnome-tweaks
            gnome-extensions-app
            dconf-editor
        )
        ;;
    *)
        warn "Unknown desktop environment '$DESKTOP_ENV'; skipping desktop-specific packages"
        ;;
esac

if [[ ${#DESKTOP_PACKAGES[@]} -gt 0 ]]; then
    for pkg in "${DESKTOP_PACKAGES[@]}"; do
        run_optional_step "Desktop package install: $pkg" sudo dnf5 install -y "$pkg"
    done
fi

log "Installing Tailscale..."
if sudo dnf5 install -y tailscale; then
    record_success "Installed tailscale"
    if sudo systemctl enable --now tailscaled; then
        record_success "Enabled and started tailscaled"
    else
        warn "Tailscale installed but tailscaled could not be enabled/started"
    fi
else
    warn "Failed to install tailscale; skipping service enablement"
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

log "Installing Claude Code..."
if npm install -g @anthropic-ai/claude-code; then
    hash -r
    record_success "Installed Claude Code"
else
    warn "Failed to install Claude Code"
fi

log "Installing Codex CLI..."
if curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_NON_INTERACTIVE=1 sh; then
    hash -r
    record_success "Installed Codex CLI"
else
    warn "Failed to install Codex CLI"
fi

log "Installing Zed IDE..."
if curl -fsSL https://zed.dev/install.sh | sh; then
    hash -r
    record_success "Installed Zed IDE"
else
    warn "Failed to install Zed IDE"
fi

log "Installing Google Antigravity CLI..."
if curl -fsSL https://antigravity.google/cli/install.sh | bash; then
    hash -r
    record_success "Installed Google Antigravity CLI"
else
    warn "Failed to install Google Antigravity CLI"
fi

log "Installing GitHub Copilot CLI..."
if curl -fsSL https://gh.io/copilot-install | bash; then
    hash -r
    record_success "Installed GitHub Copilot CLI"
else
    warn "Failed to install GitHub Copilot CLI"
fi

echo "=============================================================================="
echo " STAGE 5: SYSTEM PRODUCTION VERIFICATION"
echo "=============================================================================="
log ""
log "--- VERIFYING FEDORA WORKSTATION ENGINE STACK ---"
run_optional_step "Read Fedora release" cat /etc/fedora-release
run_optional_step "Check git version" git --version
run_optional_step "Check gh version" gh --version
run_optional_step "Check node version" node --version
run_optional_step "Check npm version" npm --version
log ""
log "--- NPM GLOBALS ---"
if npm list -g --depth=0 >> "$BOOTSTRAP_LOG" 2>&1; then
    record_success "Listed global npm packages"
else
    warn "Unable to list global npm packages"
fi
log ""
log "--- AI TOOLING ---"
run_optional_step "Check Claude Code version" claude --version
run_optional_step "Check Codex CLI version" codex --version
run_optional_step "Check GitHub Copilot CLI version" copilot --version
run_optional_step "Check Antigravity CLI version" agy --version
run_optional_step "Check Zed version" zed --version
log ""
log "--- SYSTEM SERVICES ---"
run_optional_step "Check Tailscale version" tailscale version
log ""
log "--- FLATPAKS ---"
if flatpak list --app --columns=application | grep -E "visualstudio|brave|bitwarden|obsidian|slack" >> "$BOOTSTRAP_LOG" 2>&1; then
    record_success "Verified expected Flatpak apps"
else
    warn "Some expected Flatpak apps may be missing"
fi
log "------------------------------------------------"
log "Bootstrap complete!"
log ""
run_optional_step "Run fastfetch" fastfetch

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
