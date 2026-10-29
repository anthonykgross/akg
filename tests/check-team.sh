#!/usr/bin/env bash
# Tests for scripts/check-team.sh, the SessionStart reminder.
# Runs in a temp dir with its own HOME and cache; needs git, python3 (for a local HTTP server) and jq.
# Usage: tests/check-team.sh
set -uo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
hook="$repo/scripts/check-team.sh"
tmp="$(mktemp -d)"; trap 'kill "$http_pid" 2>/dev/null; rm -rf "$tmp"' EXIT
export HOME="$tmp/home" XDG_CACHE_HOME="$tmp/cache"
mkdir -p "$HOME"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

pass=0; fail=0
REMINDER='{"systemMessage":"akg: team config updated — /akg:pull"}'

# check <name> <project dir> <expected: reminder|silent>
check() {
  local out start ms
  start=$(date +%s%N)
  out="$(CLAUDE_PROJECT_DIR="$2" "$hook" 2>&1)"; local code=$?
  ms=$(( ($(date +%s%N) - start) / 1000000 ))
  local want=""; [ "$3" = reminder ] && want="$REMINDER"
  if [ "$code" -eq 0 ] && [ "$out" = "$want" ]; then
    pass=$((pass + 1)); printf '  ok   %-58s %5d ms\n' "$1" "$ms"
  else
    fail=$((fail + 1)); printf '  FAIL %-58s %5d ms (exit %s, got: %q)\n' "$1" "$ms" "$code" "$out"
  fi
}

# project <dir> <config.yaml content>
project() { mkdir -p "$1/.claude/akg"; printf '%s\n' "$2" > "$1/.claude/akg/config.yaml"; }
team_repo() { mkdir -p "$1/.claude/akg"; echo "workflow: {tdd: true}" > "$1/.claude/akg/config.yaml"; git -C "$1" init -q -b main; git -C "$1" add -A; git -C "$1" commit -qm v1; }
commit() { echo "# $2" >> "$1/.claude/akg/config.yaml"; git -C "$1" commit -qam "$2"; }
head_of() { git -C "$1" rev-parse "${2:-HEAD}"; }

echo "No team"
mkdir -p "$tmp/bare"
check "no .claude/akg/config.yaml" "$tmp/bare" silent
project "$tmp/noext" "workflow: {tdd: true}"
check "config without extends" "$tmp/noext" silent

echo "Local team folder (git)"
team_repo "$tmp/team"
project "$tmp/p1" "extends: ../team
synced: $(head_of "$tmp/team")"
check "up to date" "$tmp/p1" silent
commit "$tmp/team" v2
check "team committed: reminder" "$tmp/p1" reminder
check "same version again: silent (once per version)" "$tmp/p1" silent
commit "$tmp/team" v3
check "another commit: reminder again" "$tmp/p1" reminder
project "$tmp/p2" "extends: \"../team\"   # quoted, with a comment
synced: '$(head_of "$tmp/team")'"
check "quoted values and comments, up to date" "$tmp/p2" silent
project "$tmp/p3" "extends: ../team
synced: 0000000000000000000000000000000000000000"
check "other project, same team: own notification state" "$tmp/p3" reminder

echo "Local team folder (no git)"
mkdir -p "$tmp/plain/.claude/akg"; echo "workflow: {tdd: true}" > "$tmp/plain/.claude/akg/config.yaml"
v="$("$repo/scripts/fetch.sh" "$tmp/plain" | sed -n 's/^version=//p')"
project "$tmp/p4" "extends: $tmp/plain
synced: $v"
check "content hash, up to date" "$tmp/p4" silent
echo "# changed" >> "$tmp/plain/.claude/akg/config.yaml"
check "content changed: reminder" "$tmp/p4" reminder

echo "Git URL (file://)"
url="file://$tmp/team"
project "$tmp/p5" "extends: $url
synced: $(head_of "$tmp/team")"
check "up to date" "$tmp/p5" silent
commit "$tmp/team" v4
check "new commit on the default branch: reminder" "$tmp/p5" reminder

echo "Pinned ref (#branch, #tag, #sha)"
git -C "$tmp/team" branch -q feature
project "$tmp/p6" "extends: $url#feature
synced: $(head_of "$tmp/team" feature)"
commit "$tmp/team" main-only
check "#feature: a commit on main only stays silent" "$tmp/p6" silent
git -C "$tmp/team" checkout -q feature; commit "$tmp/team" on-feature; git -C "$tmp/team" checkout -q main
check "#feature: a commit on feature: reminder" "$tmp/p6" reminder
git -C "$tmp/team" tag -a v1 -m v1 feature
project "$tmp/p7" "extends: $url#v1
synced: $(head_of "$tmp/team" feature)"
check "#tag (annotated) at synced: silent" "$tmp/p7" silent
sha="$(head_of "$tmp/team" main)"
project "$tmp/p8" "extends: $url#$sha
synced: $sha"
commit "$tmp/team" after-pin
check "#sha pinned: later commits stay silent" "$tmp/p8" silent

echo "Remote single file (HTTP)"
mkdir -p "$tmp/www"; echo "workflow: {tdd: true}" > "$tmp/www/team.yaml"
port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1])')
(cd "$tmp/www" && exec python3 -m http.server "$port" --bind 127.0.0.1 >/dev/null 2>&1) & http_pid=$!
for _ in $(seq 50); do curl -fs "http://127.0.0.1:$port/team.yaml" >/dev/null && break; sleep 0.1; done
h="$(curl -fsSL "http://127.0.0.1:$port/team.yaml" | sha256sum | cut -c1-12)"
project "$tmp/p9" "extends: http://127.0.0.1:$port/team.yaml
synced: $h"
check "up to date" "$tmp/p9" silent
echo "# changed" >> "$tmp/www/team.yaml"
check "file changed: reminder" "$tmp/p9" reminder
project "$tmp/p10" "extends: http://127.0.0.1:$port/missing.yaml
synced: abc"
check "404: silent" "$tmp/p10" silent
kill "$http_pid" 2>/dev/null; wait "$http_pid" 2>/dev/null
project "$tmp/p11" "extends: http://127.0.0.1:$port/team.yaml
synced: $h"
check "server down: silent" "$tmp/p11" silent

echo "Offline / slow"
project "$tmp/p12" "extends: https://10.255.255.1/acme/team.git
synced: abc"
check "unreachable git host: silent within ~2 s" "$tmp/p12" silent
project "$tmp/p13" "extends: ../does-not-exist
synced: abc"
check "missing local folder: silent" "$tmp/p13" silent

echo "Read-only cache"
team_repo "$tmp/team2"
project "$tmp/p14" "extends: ../team2
synced: 0000000000000000000000000000000000000000"
chmod -R a-w "$XDG_CACHE_HOME" 2>/dev/null || mkdir -p "$XDG_CACHE_HOME"; chmod a-w "$XDG_CACHE_HOME"
check "cache not writable: still exits 0" "$tmp/p14" reminder
chmod -R u+w "$XDG_CACHE_HOME"

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
