#!/usr/bin/env bash
# Scaffold helper for eval cases: lay out a fixture in the run workspace (cwd),
# with the team repo as a sibling (../team), like fixtures/try.sh does.
# Usage (from a case's scaffold.sh): "$(dirname "$0")/../lib/fixture.sh" <fixture> [--team] [--setup-done]
#   --team:       lay out the team repo as ../team (otherwise no team is nearby).
#   --setup-done: the project already ran /akg:setup against team v1 (for pull/team cases),
#                 and the team then committed v2 (see team-v2/). Implies --team.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fixture="$1"; shift
team=; setup_done=
for arg in "$@"; do
  case "$arg" in
    --team) team=1 ;;
    --setup-done) team=1; setup_done=1 ;;
  esac
done

cp -r "$repo/fixtures/$fixture/." .
rm -f .gitkeep
[ -n "$team" ] || exit 0
rm -rf ../team && cp -r "$repo/fixtures/team" ../team

# Fixed identity and dates: commit SHAs are the same on every run, so graders can match them.
export GIT_AUTHOR_NAME=akg GIT_AUTHOR_EMAIL=akg@example.com GIT_COMMITTER_NAME=akg GIT_COMMITTER_EMAIL=akg@example.com
export GIT_AUTHOR_DATE="2026-01-01T00:00:00Z" GIT_COMMITTER_DATE="2026-01-01T00:00:00Z"
git -C ../team init -q -b main
git -C ../team add -A
git -C ../team commit -qm "team config v1"

if [ -n "$setup_done" ]; then
  v1="$(git -C ../team rev-parse HEAD)"
  cp -r "$(dirname "${BASH_SOURCE[0]}")/setup-done/." .
  sed -i "s/__SYNCED__/$v1/" .claude/akg/config.yaml
  cp -r "$(dirname "${BASH_SOURCE[0]}")/team-v2/." ../team/
  export GIT_AUTHOR_DATE="2026-01-02T00:00:00Z" GIT_COMMITTER_DATE="2026-01-02T00:00:00Z"
  git -C ../team add -A
  git -C ../team commit -qm "team config v2"
fi
