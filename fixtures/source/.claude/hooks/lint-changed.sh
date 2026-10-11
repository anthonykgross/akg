#!/usr/bin/env bash
# Lint the file Claude just edited.
file="$(jq -r '.tool_input.file_path // empty')"
[ -n "$file" ] && npx eslint "$file" || true
