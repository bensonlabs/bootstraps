#!/usr/bin/env bash
# Fedora bootstrap entrypoint; validation runs against the current Fedora image.
# ==============================================================================
# UNATTENDED AI DEVELOPMENT ENVIRONMENT BOOTSTRAP - FEDORA (DNF5)
# ==============================================================================
set -euo pipefail

BOOTSTRAP_LOG="${HOME}/bootstrap_fedora_$(date +%Y%m%d_%H%M%S).log"
WARNINGS=()
SUCCESSES=()
DESKTOP_ENV="${XDG_CURRENT_DESKTOP:-unknown}"
SKIP_FLATPAK_INSTALLS=0
FLATPAK_INSTALLED_APPS=""
FATAL_ERROR=0
INTERACTIVE=1
INSTALL_CORE=1
INSTALL_DEVELOPMENT=1
INSTALL_VSCODE=1
INSTALL_EDGE=1
INSTALL_FLATPAKS=1
INSTALL_TAILSCALE=1
INSTALL_AI=1
DRY_RUN=0

for arg in "$@"; do
    case "$arg" in
        --all) INTERACTIVE=0 ;;
        --dry-run) DRY_RUN=1 ;;
    esac
done
# Run before logging, selection, or any installation steps.
check_architecture() {
    local detected
    detected="$(uname -m)" || return 1
    case "$detected" in
        x86_64|amd64) ARCH=x86_64 ;;
        arm64|aarch64)
            ARCH=arm64
            echo "WARN: fedora/arm64 is experimental; installation is not supported by this bootstrap yet." >&2
            if [[ "$DRY_RUN" -ne 1 ]]; then
                echo "ERROR: Use --dry-run to preview the plan; use a supported x86_64 machine for installation." >&2
                return 1
            fi
            ;;
        *)
            echo "ERROR: Unsupported fedora architecture: $detected. See docs/platform-support.md." >&2
            return 1
            ;;
    esac
    echo "Architecture: fedora/$ARCH"
}

check_architecture || exit 1

if [[ "$DRY_RUN" -eq 1 ]]; then
    BOOTSTRAP_LOG="${TMPDIR:-/tmp}/bootstrap_fedora_dry_run_$(date +%Y%m%d_%H%M%S).log"
fi

BASE_PACKAGES=(
    curl
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

DEVELOPMENT_PACKAGES=(
    gcc
    gcc-c++
    make
    automake
    autoconf
    kernel-devel
    cmake
    pkgconf-pkg-config
    libtool
    patch
    bison
    flex
)

FLATPAK_APPS=(
    com.brave.Browser
    com.bitwarden.desktop
    md.obsidian.Obsidian
    com.slack.Slack
    com.openai.chatgpt
    com.anthropic.claude
)

VSCODE_REPO_FILE="/etc/yum.repos.d/vscode.repo"
EDGE_REPO_FILE="/etc/yum.repos.d/microsoft-edge.repo"

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

component_name() {
    case "$1" in
        1) echo "Core packages" ;;
        2) echo "Development toolchain" ;;
        3) echo "Visual Studio Code (RPM)" ;;
        4) echo "Microsoft Edge (RPM)" ;;
        5) echo "Flatpak applications" ;;
        6) echo "Tailscale" ;;
        7) echo "AI CLI tools" ;;
    esac
}

component_selected() {
    case "$1" in
        1) [[ "$INSTALL_CORE" -eq 1 ]] ;;
        2) [[ "$INSTALL_DEVELOPMENT" -eq 1 ]] ;;
        3) [[ "$INSTALL_VSCODE" -eq 1 ]] ;;
        4) [[ "$INSTALL_EDGE" -eq 1 ]] ;;
        5) [[ "$INSTALL_FLATPAKS" -eq 1 ]] ;;
        6) [[ "$INSTALL_TAILSCALE" -eq 1 ]] ;;
        7) [[ "$INSTALL_AI" -eq 1 ]] ;;
    esac
}

toggle_component() {
    case "$1" in
        1) INSTALL_CORE=$((1 - INSTALL_CORE)) ;;
        2) INSTALL_DEVELOPMENT=$((1 - INSTALL_DEVELOPMENT)) ;;
        3) INSTALL_VSCODE=$((1 - INSTALL_VSCODE)) ;;
        4) INSTALL_EDGE=$((1 - INSTALL_EDGE)) ;;
        5) INSTALL_FLATPAKS=$((1 - INSTALL_FLATPAKS)) ;;
        6) INSTALL_TAILSCALE=$((1 - INSTALL_TAILSCALE)) ;;
        7) INSTALL_AI=$((1 - INSTALL_AI)) ;;
    esac
}

select_components() {
    local choice mark

    if [[ "$INTERACTIVE" -eq 0 || ! -t 0 ]]; then
        return 0
    fi

    while true; do
        clear
        echo "Fedora workstation bootstrap"
        echo "Toggle items with their number. Press Enter when finished."
        echo
        for choice in {1..7}; do
            if component_selected "$choice"; then mark="x"; else mark=" "; fi
            printf '[%s] %s) %s\n' "$mark" "$choice" "$(component_name "$choice")"
        done
        echo
        read -r -p "Toggle item(s), or press Enter to continue: " choices
        [[ -z "$choices" ]] && break
        for choice in $choices; do
            if [[ "$choice" =~ ^[1-7]$ ]]; then
                toggle_component "$choice"
            else
                echo "Ignoring invalid selection: $choice"
            fi
        done
    done

    echo
    echo "Selected components:"
    for choice in {1..7}; do
        if component_selected "$choice"; then
            echo "  - $(component_name "$choice")"
        fi
    done
    read -r -p "Proceed with installation? [y/N] " confirmation
    [[ "$confirmation" =~ ^[Yy]$ ]] || exit 0
}

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
    log "RUN: $description"
    if "$@" 2>&1 | tee -a "$BOOTSTRAP_LOG"; then
        record_success "$description"
        return 0
    fi

    fatal "$description failed"
    return 1
}

run_optional_step() {
    local description="$1"
    shift
    log "RUN: $description"
    if "$@" 2>&1 | tee -a "$BOOTSTRAP_LOG"; then
        record_success "$description"
    else
        warn "$description failed; continuing"
    fi
}

run_optional_pipe_step() {
    local description="$1"
    local command="$2"
    log "RUN: $description"
    if bash -c "$command" 2>&1 | tee -a "$BOOTSTRAP_LOG"; then
        record_success "$description"
    else
        warn "$description failed; continuing"
    fi
}

ensure_sudo_session() {
    log "Requesting sudo access for system-level install steps..."
    if sudo -v 2>&1 | tee -a "$BOOTSTRAP_LOG"; then
        record_success "Cached sudo credentials"
    else
        fatal "Unable to obtain sudo credentials"
        return 1
    fi
}

check_dnf_health() {
    log "Running DNF health preflight..."

    if ! sudo dnf5 check 2>&1 | tee -a "$BOOTSTRAP_LOG"; then
        fatal "DNF health check failed; package state appears inconsistent. Restore a clean snapshot or repair the system before re-running."
        return 1
    fi

    record_success "DNF health preflight passed"
}

check_platform() {
    if [[ ! -r /etc/fedora-release ]] || ! grep -q '^Fedora' /etc/os-release; then
        fatal "This script supports Fedora only"
        return 1
    fi

    if ! command -v dnf5 >/dev/null 2>&1; then
        fatal "dnf5 is required but was not found"
        return 1
    fi
}

create_pre_bootstrap_snapshot() {
    local filesystem

    filesystem="$(findmnt -n -o FSTYPE / 2>/dev/null || true)"
    if [[ "$filesystem" != "btrfs" ]]; then
        warn "Root filesystem is '$filesystem', not Btrfs; skipping Snapper snapshot"
        return 0
    fi

    if ! command -v snapper >/dev/null 2>&1; then
        run_optional_step "Install Snapper for rollback protection" sudo dnf5 install -y snapper
    fi

    if ! command -v snapper >/dev/null 2>&1; then
        fatal "Snapper is unavailable on a Btrfs root; refusing to continue without a pre-bootstrap snapshot"
        return 1
    fi

    if ! sudo snapper list-configs 2>/dev/null | awk 'NR > 1 && $1 == "root" { found = 1 } END { exit !found }'; then
        log "Creating Snapper root configuration..."
        if ! sudo snapper -c root create-config / 2>&1 | tee -a "$BOOTSTRAP_LOG"; then
            fatal "Unable to create the Snapper root configuration"
            return 1
        fi
    fi

    run_step "Create pre-bootstrap Snapper snapshot" sudo snapper -c root create --description "Before Fedora bootstrap $(date +%Y-%m-%d_%H-%M-%S)"
}

install_flatpaks() {
    local app

    if ! command -v flatpak >/dev/null 2>&1; then
        run_step "Install Flatpak runtime" sudo dnf5 install -y flatpak || return 1
    fi

    if ! sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>&1 | tee -a "$BOOTSTRAP_LOG"; then
        warn "Failed to add Flathub remote; skipping Flatpak app installs"
        SKIP_FLATPAK_INSTALLS=1
        return 0
    fi

    record_success "Configured Flathub remote"
    FLATPAK_INSTALLED_APPS="$(flatpak list --app --columns=application 2>/dev/null || true)"

    for app in "${FLATPAK_APPS[@]}"; do
        if grep -Fxq "$app" <<< "$FLATPAK_INSTALLED_APPS"; then
            record_success "Flatpak already installed: $app"
        else
            run_optional_step "Install Flatpak: $app" sudo flatpak install flathub "$app" -y
        fi
    done
}

install_microsoft_signing_key() {
    if sudo rpm -q gpg-pubkey --qf '%{summary}\n' 2>/dev/null | grep -Fq 'Microsoft'; then
        record_success "Microsoft signing key already imported"
    elif sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc 2>&1 | tee -a "$BOOTSTRAP_LOG"; then
        record_success "Imported Microsoft signing key"
    else
        fatal "Failed to import the Microsoft signing key"
        return 1
    fi
}

install_vscode_rpm() {
    log "Configuring the official Microsoft VS Code RPM repository..."

    if ! sudo tee "$VSCODE_REPO_FILE" > /dev/null <<'EOF' 2>>"$BOOTSTRAP_LOG"
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
autorefresh=1
type=rpm-md
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
    then
        fatal "Failed to configure the Microsoft VS Code RPM repository"
        return 1
    fi

    record_success "Configured Microsoft VS Code RPM repository"

    if rpm -q code >> "$BOOTSTRAP_LOG" 2>&1; then
        record_success "VS Code RPM already installed"
    else
        run_step "Install VS Code RPM" sudo dnf5 install -y code || return 1
    fi
}

install_edge_rpm() {
    log "Configuring the official Microsoft Edge stable RPM repository..."

    if ! sudo tee "$EDGE_REPO_FILE" > /dev/null <<'EOF' 2>>"$BOOTSTRAP_LOG"
[microsoft-edge]
name=Microsoft Edge
baseurl=https://packages.microsoft.com/yumrepos/edge-stable
enabled=1
autorefresh=1
type=rpm-md
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
    then
        fatal "Failed to configure the Microsoft Edge RPM repository"
        return 1
    fi

    record_success "Configured Microsoft Edge stable RPM repository"

    if rpm -q microsoft-edge-stable >> "$BOOTSTRAP_LOG" 2>&1; then
        record_success "Microsoft Edge stable RPM already installed"
    else
        run_step "Install Microsoft Edge stable RPM" sudo dnf5 install -y microsoft-edge-stable || return 1
    fi
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

    local npm_path_line="export PATH=\"\$HOME/.npm-global/bin:\$PATH\""
    if ! grep -Fqx "$npm_path_line" "$HOME/.bashrc" 2>/dev/null; then
        echo "$npm_path_line" >> "$HOME/.bashrc"
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
    if bash -c "$command" 2>&1 | tee -a "$BOOTSTRAP_LOG"; then
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
        warn "Skipping Flatpak verification because Flatpak setup failed"
        return 0
    fi

    FLATPAK_INSTALLED_APPS="$(flatpak list --app --columns=application 2>/dev/null || true)"

    for app in "${FLATPAK_APPS[@]}"; do
        if grep -Fxq "$app" <<< "$FLATPAK_INSTALLED_APPS"; then
            record_success "Verified Flatpak: $app"
        else
            warn "Missing expected Flatpak: $app"
        fi
    done
}

verify_vscode_rpm() {
    local package_metadata

    if ! rpm -q code >> "$BOOTSTRAP_LOG" 2>&1; then
        warn "VS Code RPM package is not installed"
        return 0
    fi

    package_metadata="$(rpm -q code --qf '%{NAME} %{VERSION}-%{RELEASE} %{VENDOR} %{PACKAGER}\n')"
    log "VS Code RPM: $package_metadata"

    if [[ "$package_metadata" == *"Microsoft"* ]]; then
        record_success "Verified VS Code is installed from the Microsoft RPM package"
    else
        warn "VS Code is installed, but its RPM vendor/packager is not Microsoft: $package_metadata"
    fi

        FLATPAK_INSTALLED_APPS="$(flatpak list --app --columns=application 2>/dev/null || true)"
        if grep -Fxq "com.visualstudio.code" <<< "$FLATPAK_INSTALLED_APPS"; then
        warn "Flatpak VS Code is installed alongside the RPM package"
    else
        record_success "Verified Flatpak VS Code is not installed"
    fi
}

verify_edge_rpm() {
    local package_metadata

    if ! rpm -q microsoft-edge-stable >> "$BOOTSTRAP_LOG" 2>&1; then
        warn "Microsoft Edge stable RPM package is not installed"
        return 0
    fi

    package_metadata="$(rpm -q microsoft-edge-stable --qf '%{NAME} %{VERSION}-%{RELEASE} %{VENDOR} %{PACKAGER}\n')"
    log "Microsoft Edge RPM: $package_metadata"

    if [[ "$package_metadata" == *"Microsoft"* ]]; then
        record_success "Verified Microsoft Edge is installed from the Microsoft RPM package"
    else
        warn "Microsoft Edge is installed, but its RPM vendor/packager is not Microsoft: $package_metadata"
    fi

    if grep -Fxq "com.microsoft.Edge" <<< "$FLATPAK_INSTALLED_APPS"; then
        warn "Flatpak Microsoft Edge is installed alongside the RPM package"
    else
        record_success "Verified Flatpak Microsoft Edge is not installed"
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

select_components

if [[ "$DRY_RUN" -eq 1 ]]; then
    log "DRY RUN: no system changes will be made."
    log "Selected components:"
    for choice in {1..7}; do
        component_selected "$choice" && log "  - $(component_name "$choice")"
    done
    [[ "$INSTALL_CORE" -eq 1 ]] && log "Would install Fedora base packages: ${BASE_PACKAGES[*]}"
    [[ "$INSTALL_DEVELOPMENT" -eq 1 ]] && log "Would install development packages: ${DEVELOPMENT_PACKAGES[*]}"
    [[ "$INSTALL_VSCODE" -eq 1 ]] && log "Would configure and install VS Code from the Microsoft RPM repository"
    [[ "$INSTALL_EDGE" -eq 1 ]] && log "Would configure and install Microsoft Edge stable from the Microsoft RPM repository"
    [[ "$INSTALL_VSCODE" -eq 1 ]] && log "Would write $VSCODE_REPO_FILE and import the Microsoft signing key"
    [[ "$INSTALL_EDGE" -eq 1 ]] && log "Would write $EDGE_REPO_FILE"
    log "Would write /etc/dnf/dnf.conf.d/99-bootstrap.conf and create a pre-bootstrap snapshot when supported"
    [[ "$INSTALL_FLATPAKS" -eq 1 ]] && log "Would install Flatpaks: ${FLATPAK_APPS[*]}"
    [[ "$INSTALL_TAILSCALE" -eq 1 ]] && log "Would install and enable Tailscale"
    [[ "$INSTALL_AI" -eq 1 ]] && log "Would install Claude Code and Codex CLI via npm"
    exit 0
fi

log "=============================================================================="
log " FEDORA AI DEV BOOTSTRAP"
log " Log file: $BOOTSTRAP_LOG"
log " Detected desktop: $DESKTOP_ENV"
log "=============================================================================="

print_stage "STAGE 0: PACKAGE MANAGER PREFLIGHT"
check_platform || exit 1
ensure_sudo_session || exit 1
check_dnf_health || exit 1
create_pre_bootstrap_snapshot || exit 1

print_stage "STAGE 1: SYSTEM UPDATES & OPTIMIZATIONS"
sudo mkdir -p /etc/dnf/dnf.conf.d
cat << 'EOF' | sudo tee /etc/dnf/dnf.conf.d/99-bootstrap.conf | tee -a "$BOOTSTRAP_LOG" >/dev/null
[main]
fastestmirror=True
max_parallel_downloads=10
defaultyes=True
EOF
record_success "Configured /etc/dnf/dnf.conf.d/99-bootstrap.conf"

run_step "System upgrade" sudo dnf5 upgrade -y || exit 1
SELECTED_DNF_PACKAGES=()
if [[ "$INSTALL_DEVELOPMENT" -eq 1 ]]; then
    SELECTED_DNF_PACKAGES+=("${DEVELOPMENT_PACKAGES[@]}")
fi
if [[ "$INSTALL_CORE" -eq 1 ]]; then
    SELECTED_DNF_PACKAGES+=("${BASE_PACKAGES[@]}")
fi
if [[ ${#SELECTED_DNF_PACKAGES[@]} -gt 0 ]]; then
    run_step "Selected development and base package install" sudo dnf5 install -y "${SELECTED_DNF_PACKAGES[@]}" || exit 1
else
    log "Skipping core and development package installation"
fi
run_optional_step "Git config core.fscache" git config --global core.fscache true
run_optional_step "Git config core.preloadindex" git config --global core.preloadindex true
run_optional_step "Git config gc.auto" git config --global gc.auto 256

print_stage "STAGE 2: APPLICATION RUNTIMES & REPOSITORIES"
if [[ "$INSTALL_FLATPAKS" -eq 1 ]]; then install_flatpaks; fi
if [[ "$INSTALL_VSCODE" -eq 1 || "$INSTALL_EDGE" -eq 1 ]]; then install_microsoft_signing_key; fi
if [[ "$INSTALL_VSCODE" -eq 1 ]]; then install_vscode_rpm; fi
if [[ "$INSTALL_EDGE" -eq 1 ]]; then install_edge_rpm; fi
if [[ "$INSTALL_CORE" -eq 1 ]]; then install_desktop_packages; else log "Desktop utility installation skipped with core packages"; fi
if [[ "$INSTALL_TAILSCALE" -eq 1 ]]; then install_tailscale; fi

print_stage "STAGE 3: CLOUD AI CLI TOOLING"
if [[ "$INSTALL_AI" -eq 1 ]]; then
    ensure_npm_global_path || exit 1
    install_shell_cli "Claude Code" "npm install -g @anthropic-ai/claude-code" claude
    install_shell_cli "Codex CLI" "npm install -g @openai/codex" codex
fi

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
if [[ "$INSTALL_AI" -eq 1 ]]; then
    verify_ai_clis
else
    log "AI CLI verification skipped"
fi
log ""
log "--- SYSTEM SERVICES ---"
run_optional_step "Check Tailscale version" tailscale version
log ""
log "--- FLATPAKS ---"
if [[ "$INSTALL_FLATPAKS" -eq 1 ]]; then verify_flatpaks; else log "Flatpak verification skipped"; fi
log "--- VS CODE RPM ---"
if [[ "$INSTALL_VSCODE" -eq 1 ]]; then verify_vscode_rpm; else log "VS Code verification skipped"; fi
log "--- MICROSOFT EDGE RPM ---"
if [[ "$INSTALL_EDGE" -eq 1 ]]; then verify_edge_rpm; else log "Microsoft Edge verification skipped"; fi
log "------------------------------------------------"
log "Bootstrap complete!"
log ""
run_optional_step "Run fastfetch" fastfetch
