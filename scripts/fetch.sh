#!/usr/bin/env bash
# Resolve an akg source (team config or marketplace) to a local path and a version.
#
# Usage: fetch.sh <source>[#ref] [base-dir]
#   source:   github:owner/repo | git URL | https URL to a .yaml/.yml file | local path
#   ref:      optional branch, tag or commit for git sources and local git repos
#             (ignored for single files, with a warning= line)
#   base-dir: directory a relative local path resolves against (default: cwd)
#
# Prints key=value lines:
#   kind=dir|file      path=<absolute path>      version=<commit sha | content hash>
#   warning=<text>     (optional)
# Remote sources are cached in ~/.cache/akg/ and refreshed on every call.
# Remote files also keep a copy per version: <dir>/<version>.yaml.
set -euo pipefail

src="${1:?usage: fetch.sh <source>[#ref] [base-dir]}"
ref=""
case "$src" in *#*) ref="${src##*#}"; src="${src%#*}" ;; esac
base="${2:-$PWD}"
cache="${XDG_CACHE_HOME:-$HOME/.cache}/akg"

slug() { printf '%s' "$1" | sed -E 's#^[a-z+]+:/*##; s#[^A-Za-z0-9._-]+#-#g; s#-+$##'; }
hash_files() { sort | xargs -r cat | sha256sum | cut -c1-12; }

# One cache per source and ref, so two branches never overwrite each other.
fetch_git() {
  local url="$1" dir="$cache/$(slug "$1${ref:+#$ref}")"
  if [ ! -d "$dir/.git" ]; then
    git init -q "$dir"
    git -C "$dir" remote add origin "$url"
  fi
  # Works the same for the default branch (HEAD), a branch, a tag or a commit.
  git -C "$dir" fetch -q --depth 1 origin "${ref:-HEAD}"
  git -C "$dir" reset -q --hard FETCH_HEAD
  echo "kind=dir"; echo "path=$dir"; echo "version=$(git -C "$dir" rev-parse HEAD)"
}

no_ref_for_files() {
  [ -z "$ref" ] || echo "warning=#$ref ignored: a single file has no branch (put it in the URL)"
}

fetch_file() {
  local url="$1" dir="$cache/$(slug "$1")"
  mkdir -p "$dir"
  curl -fsSL --max-time 10 -o "$dir/config.yaml" "$url"
  local v; v="$(sha256sum "$dir/config.yaml" | cut -c1-12)"
  # Keep each version so /akg:pull can diff against the last synced one.
  cp "$dir/config.yaml" "$dir/$v.yaml"
  echo "kind=file"; echo "path=$dir/config.yaml"; echo "version=$v"
}

case "$src" in
  github:*)                     fetch_git "https://github.com/${src#github:}.git" ;;
  http*://*.yaml|http*://*.yml) no_ref_for_files; fetch_file "$src" ;;
  http*://*|git@*|ssh://*|file://*) fetch_git "$src" ;;
  *)
    case "$src" in /*) p="$src" ;; *) p="$base/$src" ;; esac
    if [ -f "$p" ]; then
      no_ref_for_files
      echo "kind=file"; echo "path=$(realpath "$p")"; echo "version=$(sha256sum "$p" | cut -c1-12)"
    elif [ -d "$p" ] && [ -n "$ref" ]; then
      # A ref on a local repo: read that ref from a cached copy, never the working tree.
      fetch_git "file://$(realpath "$p")"
    elif [ -d "$p" ]; then
      p="$(realpath "$p")"
      # Commit SHA only if the directory is itself the root of a git repo with commits.
      if [ "$(git -C "$p" rev-parse --show-toplevel 2>/dev/null)" = "$p" ] \
         && v="$(git -C "$p" rev-parse --verify -q HEAD)"; then :
      else
        # A team folder may have no .claude-plugin/: find then fails, which pipefail must not see.
        v="$( { find "$p/.claude/akg" "$p/.claude-plugin" -type f 2>/dev/null || true; } | hash_files)"
      fi
      echo "kind=dir"; echo "path=$p"; echo "version=$v"
    else
      echo "error=not found: $p" >&2; exit 1
    fi
    ;;
esac
