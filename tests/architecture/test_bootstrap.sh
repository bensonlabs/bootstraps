#!/usr/bin/env bash
# Exercise complete entrypoints with mocked detection and blocked installers.
set -euo pipefail
platform="${1:?platform required}"
case "$platform" in
    fedora|ubuntu) script="scripts/bootstrap_${platform}.sh" ;;
    macos) script="scripts/bootstrap_macOS.sh" ;;
    *) echo "Unknown test platform: $platform" >&2; exit 1 ;;
esac
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
mkdir -p "$scratch/bin"
cat > "$scratch/bin/uname" <<'MOCK'
#!/usr/bin/env bash
case "$1" in
    -m) echo "$TEST_MACHINE" ;;
    -s) echo Darwin ;;
    *) exit 1 ;;
esac
MOCK
cat > "$scratch/bin/sysctl" <<'MOCK'
#!/usr/bin/env bash
echo "${TEST_TRANSLATED:-0}"
MOCK
cat > "$scratch/bin/sw_vers" <<'MOCK'
#!/usr/bin/env bash
echo 27.0
MOCK
cat > "$scratch/bin/blocked" <<'MOCK'
#!/usr/bin/env bash
echo "Unexpected installation command: $0 $*" >> "$TEST_INSTALL_TRACE"
exit 97
MOCK
chmod +x "$scratch/bin/"*
for command in sudo curl wget brew dnf5 apt-get winget; do
    ln -s blocked "$scratch/bin/$command"
done

run_case() {
    local machine="$1" preview="$2" expected="$3" message="$4" translated="${5:-0}"
    local case_dir status=0
    case_dir="$(mktemp -d "$scratch/case.XXXXXX")"
    mkdir -p "$case_dir/home" "$case_dir/tmp"
    local args=(--all)
    if [[ "$preview" == yes ]]; then args+=(--dry-run); fi
    env PATH="$scratch/bin:$PATH" HOME="$case_dir/home" TMPDIR="$case_dir/tmp" \
        TEST_MACHINE="$machine" TEST_TRANSLATED="$translated" \
        TEST_INSTALL_TRACE="$case_dir/install-trace" \
        bash "$script" "${args[@]}" > "$case_dir/output" 2>&1 || status=$?
    if [[ "$status" -ne "$expected" ]] || ! grep -Fq -- "$message" "$case_dir/output"; then
        cat "$case_dir/output" >&2
        echo "$platform/$machine preview=$preview: expected exit $expected, got $status ($message)" >&2
        exit 1
    fi
    [[ ! -e "$case_dir/install-trace" ]]
    if [[ "$expected" -ne 0 ]]; then
        # Rejection must precede even log creation.
        [[ -z "$(find "$case_dir/home" "$case_dir/tmp" -type f -print)" ]]
        if grep -Fq 'Selected components:' "$case_dir/output"; then
            echo 'Architecture rejection happened after component selection.' >&2
            exit 1
        fi
    fi
}

if [[ "$platform" == macos ]]; then
    for machine in arm64 aarch64; do
        run_case "$machine" yes 0 'Architecture: macos/arm64'
    done
    for machine in x86_64 amd64; do
        run_case "$machine" yes 0 'macos/x86_64 is legacy'
    done
    # Rosetta must not make Apple Silicon look like legacy Intel hardware.
    run_case x86_64 yes 1 'Apple Silicon detected under Rosetta' 1
    run_case x86_64 no 1 'Apple Silicon detected under Rosetta' 1
else
    for machine in x86_64 amd64; do
        run_case "$machine" yes 0 "Architecture: $platform/x86_64"
    done
    for machine in arm64 aarch64; do
        run_case "$machine" yes 0 "$platform/arm64 is experimental"
        run_case "$machine" no 1 'Use --dry-run to preview the plan'
    done
fi
for machine in i686 armv7l riscv64 unknown ''; do
    run_case "$machine" yes 1 "Unsupported $platform architecture:"
    run_case "$machine" no 1 "Unsupported $platform architecture:"
done

echo "$platform architecture behavior checks passed."
