#!/usr/bin/env bash
# Extract the team config as it was at a given version, for /akg:pull diffs.
#
# Usage: snapshot.sh <kind> <path> <version>     (kind, path, version as printed by fetch.sh)
# Prints the path of the old snapshot: a directory (kind=dir) or a file (kind=file).
# Exits 1 when that version is not available (no history, unknown commit, file version not cached).
set -euo pipefail

kind="${1:?usage: snapshot.sh <kind> <path> <version>}"
path="${2:?}"
version="${3:?}"

case "$kind" in
  dir)
    [ "$(git -C "$path" rev-parse --show-toplevel 2>/dev/null)" = "$path" ] || exit 1
    # Shallow clones may not have the old commit: fetch it by SHA (supported by GitHub/GitLab).
    git -C "$path" cat-file -e "$version^{commit}" 2>/dev/null \
      || git -C "$path" fetch -q --depth 1 origin "$version" 2>/dev/null \
      || exit 1
    out="$(mktemp -d -t akg-snapshot-XXXXXX)"
    for d in .claude/akg .claude-plugin; do
      if git -C "$path" cat-file -e "$version:$d" 2>/dev/null; then
        git -C "$path" archive "$version" "$d" | tar -x -C "$out"
      fi
    done
    echo "$out"
    ;;
  file)
    f="$(dirname "$path")/$version.yaml"
    [ -f "$f" ] || exit 1
    echo "$f"
    ;;
  *) exit 1 ;;
esac
