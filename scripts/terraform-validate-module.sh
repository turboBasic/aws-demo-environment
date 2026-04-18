#!/usr/bin/env bash
#
# Validate a single Terraform module (root or bootstrap/).
#
# Usage:
#   ./terraform-validate-module.sh [TARGET_DIR]
#
# Arguments:
#   TARGET_DIR   Directory to validate, relative to repo root (default: .)
#
# Example:
#   ./terraform-validate-module.sh bootstrap
#

set -euo pipefail

main() {
  local repo_root target_dir mise_bin

  repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  target_dir="$(resolve_target_dir "$repo_root" "${1:-.}")"
  mise_bin="$(resolve_mise)"
  run_validate "$target_dir" "$mise_bin"
}

resolve_target_dir() {
  local repo_root="$1" target="$2"
  local full_path="$repo_root/$target"

  if [[ ! -d "$full_path" ]]; then
    echo "ERROR: target directory not found: $full_path" >&2
    exit 1
  fi

  echo "$full_path"
}

resolve_mise() {
  if command -v mise >/dev/null 2>&1; then
    echo "mise"
    return
  fi

  local candidate
  for candidate in \
    /opt/homebrew/bin/mise \
    /usr/local/bin/mise \
    /home/linuxbrew/.linuxbrew/bin/mise \
    "$HOME/.local/bin/mise"; do
    if [[ -x "$candidate" ]]; then
      echo "$candidate"
      return
    fi
  done

  echo "ERROR: mise not found. Install via 'brew install mise' or see https://mise.jdx.dev/getting-started.html" >&2
  exit 1
}

run_validate() {
  local target_dir="$1" mise_bin="$2"

  cd "$target_dir"
  "$mise_bin" exec -- terraform init -backend=false -input=false -no-color >/dev/null
  exec "$mise_bin" exec -- terraform validate -no-color
}

main "$@"
