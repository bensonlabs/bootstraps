#!/usr/bin/env bash
set -euo pipefail

script="scripts/bootstrap_macOS.sh"
contains() { grep -Fq -- "$1" "$script"; }
absent() { ! grep -Fqi "$1" "$script"; }

contains 'select_components'
contains '--dry-run'
contains 'REQUIRED_MACOS_MAJOR_VERSION=27'
contains 'BREW_PKG_URL'
contains 'INSTALL_CUSTOMIZATION'
absent 'antigravity'
absent 'copilot'
absent 'zed'

echo "macOS bootstrap contract checks passed."

bash tests/architecture/test_bootstrap.sh macos
