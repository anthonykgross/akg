#!/usr/bin/env bash
# Run akg's eval suite. Extra args go to `claude plugin eval` (e.g. --case 'setup-*' --runs 1).
# Needs the Bash sandbox (Linux: bubblewrap + socat).
set -euo pipefail
cd "$(dirname "$0")/.."
# --scaffold: cases lay out fixtures/ in the run workspace (our own scripts, evals/lib/fixture.sh).
# --ablation none: the cases invoke akg's slash commands; a no-plugin arm says nothing.
exec claude plugin eval . --scaffold --trust-plugin --ablation none \
  --allow-tools Bash Write Edit "$@"
