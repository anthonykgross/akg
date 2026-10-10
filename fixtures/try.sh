#!/usr/bin/env bash
# Copy the fixtures to a temp dir so tests never write into this repo,
# and so this repo's CLAUDE.md is not loaded as parent context.
# Usage: fixtures/try.sh [fixture]   (default: no-team)
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
fixture="${1:-no-team}"
[ -d "$repo/fixtures/$fixture" ] || { echo "unknown fixture: $fixture" >&2; exit 1; }

work="$(mktemp -d -t akg-fixtures-XXXXXX)"
cp -r "$repo/fixtures/." "$work/"
rm -f "$work/try.sh" "$work/README.md"

# The team repo is a git repo, so /akg:pull and the hook can track commits.
git -C "$work/team" init -q
git -C "$work/team" add -A
git -C "$work/team" -c user.name=akg -c user.email=akg@example.com commit -qm "team config v1"

echo "Fixtures copied to: $work"
echo "Run:"
echo "  cd $work/$fixture && claude --plugin-dir $repo"
