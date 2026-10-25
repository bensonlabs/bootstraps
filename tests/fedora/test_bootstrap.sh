#!/usr/bin/env bash
set -euo pipefail

script="scripts/bootstrap_fedora.sh"

assert_contains() {
    local pattern="$1"
    grep -Fq "$pattern" "$script" || {
        echo "Expected Fedora bootstrap content was not found: $pattern" >&2
        exit 1
    }
}

assert_not_contains() {
    local pattern="$1"
    if grep -Fqi "$pattern" "$script"; then
        echo "Unexpected Fedora bootstrap content was found: $pattern" >&2
        exit 1
    fi
}

assert_contains 'select_components'
assert_contains 'if [[ "${1:-}" == "--all" ]]'
assert_contains 'check_platform'
assert_contains 'dnf.conf.d/99-bootstrap.conf'
assert_contains 'create_pre_bootstrap_snapshot'
assert_contains 'packages.microsoft.com/yumrepos/vscode'
assert_contains 'packages.microsoft.com/yumrepos/edge-stable'
assert_contains 'microsoft-edge-stable'
assert_contains 'com.visualstudio.code'
assert_not_contains 'zed'
assert_not_contains 'copilot'
assert_not_contains 'antigravity'

echo "Fedora bootstrap contract checks passed."
