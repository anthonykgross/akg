#!/usr/bin/env bash
# SessionStart hook: tell the user, once per team version, that the team config changed.
# Silent when: no akg config, no extends, up to date, offline/slow (~2 s), or already notified.
# Never fails the session: every error path exits 0 without output.
set -uo pipefail

project="${CLAUDE_PROJECT_DIR:-$PWD}"
config="$project/.claude/akg/config.yaml"
[ -f "$config" ] || exit 0

# Top-level scalar from config.yaml, without quotes or trailing comment.
yaml_get() {
  sed -n "s/^$1:[[:space:]]*//p" "$config" | head -1 \
    | sed -E 's/[[:space:]]+#.*$//; s/^["'\'']//; s/["'\'']$//; s/[[:space:]]+$//'
}

extends="$(yaml_get extends)"
synced="$(yaml_get synced)"
[ -n "$extends" ] || exit 0
ref=""
case "$extends" in *#*) ref="${extends##*#}" ;; esac
src="${extends%#*}"

export GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=2"

# Commit of the configured ref on the remote: HEAD, a branch, a tag (peeled) or a commit SHA.
remote_sha() {
  if [ -z "$ref" ]; then
    timeout 2 git ls-remote "$1" HEAD 2>/dev/null | cut -f1
  elif printf '%s' "$ref" | grep -Eq '^[0-9a-f]{40}$'; then
    echo "$ref"
  else
    timeout 2 git ls-remote "$1" "refs/heads/$ref" "refs/tags/$ref" "refs/tags/$ref^{}" 2>/dev/null \
      | awk -v r="$ref" '$2=="refs/heads/"r{h=$1} $2=="refs/tags/"r"^{}"{p=$1} $2=="refs/tags/"r{t=$1}
                         END{print h ? h : (p ? p : t)}'
  fi
}

case "$src" in
  github:*)                     latest="$(remote_sha "https://github.com/${src#github:}.git")" ;;
  http*://*.yaml|http*://*.yml) latest="$(curl -fsSL --max-time 2 "$src" 2>/dev/null | sha256sum | cut -c1-12)"
                                # an empty download still hashes: treat as offline
                                [ "$latest" = "e3b0c44298fc" ] && latest="" ;;
  http*://*|git@*|ssh://*|file://*) latest="$(remote_sha "$src")" ;;
  *)                            latest="$("$(dirname "$0")/fetch.sh" "$extends" "$project" 2>/dev/null | sed -n 's/^version=//p')" ;;
esac

[ -n "$latest" ] || exit 0
[ "$latest" = "$synced" ] && exit 0

state_dir="${XDG_CACHE_HOME:-$HOME/.cache}/akg/notified"
state="$state_dir/$(printf '%s' "$project" | sed -E 's#[^A-Za-z0-9._-]+#-#g')"
[ "$(cat "$state" 2>/dev/null)" = "$latest" ] && exit 0
mkdir -p "$state_dir" && printf '%s\n' "$latest" > "$state"

# JSON systemMessage: shown to the user only, not added to Claude's context.
printf '{"systemMessage":"akg: team config updated — /akg:pull"}\n'
