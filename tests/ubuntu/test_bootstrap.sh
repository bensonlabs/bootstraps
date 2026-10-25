#!/usr/bin/env bash
set -euo pipefail

script="scripts/bootstrap_ubuntu.sh"
contains() { grep -Fq "$1" "$script"; }
absent() { ! grep -Fqi "$1" "$script"; }

contains 'select_components'
contains 'check_platform'
contains 'create_pre_bootstrap_snapshot'
contains 'apt.conf.d/99parallel-downloads'
contains 'packages.microsoft.com/repos/code'
absent 'antigravity'
absent 'copilot'
absent 'zed'

echo "Ubuntu bootstrap contract checks passed."
