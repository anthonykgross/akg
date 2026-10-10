#!/usr/bin/env bash
# Resolve an akg source (team config or marketplace) to a local path and a version.
#
# Usage: fetch.sh <source> [base-dir]
#   source:   github:owner/repo | git URL | https URL to a .yaml/.yml file | local path
#   base-dir: directory a relative local path resolves against (default: cwd)
#
# Prints key=value lines:
#   kind=dir|file      path=<absolute path>      version=<commit sha | content hash>
# Remote sources are cached in ~/.cache/akg/ and refreshed on every call.
set -euo pipefail

src="${1:?usage: fetch.sh <source> [base-dir]}"
base="${2:-$PWD}"
cache="${XDG_CACHE_HOME:-$HOME/.cache}/akg"
mkdir -p "$cache"

slug() { printf '%s' "$1" | sed -E 's#^[a-z+]+:/*##; s#[^A-Za-z0-9._-]+#-#g; s#-+$##'; }
hash_files() { sort | xargs -r cat | sha256sum | cut -c1-12; }

fetch_git() {
  local url="$1" dir="$cache/$(slug "$1")"
  if [ -d "$dir/.git" ]; then
    git -C "$dir" fetch -q --depth 1 origin HEAD
    git -C "$dir" reset -q --hard FETCH_HEAD
  else
    git clone -q --depth 1 "$url" "$dir"
  fi
  echo "kind=dir"; echo "path=$dir"; echo "version=$(git -C "$dir" rev-parse HEAD)"
}

fetch_file() {
  local url="$1" dir="$cache/$(slug "$1")"
  mkdir -p "$dir"
  curl -fsSL --max-time 10 -o "$dir/config.yaml" "$url"
  echo "kind=file"; echo "path=$dir/config.yaml"; echo "version=$(sha256sum "$dir/config.yaml" | cut -c1-12)"
}

case "$src" in
  github:*)                     fetch_git "https://github.com/${src#github:}.git" ;;
  http*://*.yaml|http*://*.yml) fetch_file "$src" ;;
  http*://*|git@*|ssh://*)      fetch_git "$src" ;;
  *)
    case "$src" in /*) p="$src" ;; *) p="$base/$src" ;; esac
    if [ -f "$p" ]; then
      echo "kind=file"; echo "path=$(realpath "$p")"; echo "version=$(sha256sum "$p" | cut -c1-12)"
    elif [ -d "$p" ]; then
      p="$(realpath "$p")"
      # Commit SHA only if the directory is itself the root of a git repo with commits.
      if [ "$(git -C "$p" rev-parse --show-toplevel 2>/dev/null)" = "$p" ] \
         && v="$(git -C "$p" rev-parse --verify -q HEAD)"; then :
      else
        v="$(find "$p/.claude/akg" "$p/.claude-plugin" -type f 2>/dev/null | hash_files)"
      fi
      echo "kind=dir"; echo "path=$p"; echo "version=$v"
    else
      echo "error=not found: $p" >&2; exit 1
    fi
    ;;
esac
