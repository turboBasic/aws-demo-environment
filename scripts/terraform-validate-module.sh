#!/usr/bin/env bash
# Validate a single Terraform module (root or bootstrap/).
# Pass the target directory relative to the repo root as the first argument
# (defaults to the repo root). Uses the repo-pinned terraform version via mise.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DIR="$REPO_ROOT/${1:-.}"

if [[ ! -d "$TARGET_DIR" ]]; then
    echo "ERROR: target directory not found: $TARGET_DIR" >&2
    exit 1
fi

# Resolve mise: PATH first, then common Homebrew / installer locations on macOS & Linux.
if command -v mise >/dev/null 2>&1; then
    MISE_BIN="mise"
else
    MISE_BIN=""
    for candidate in \
        /opt/homebrew/bin/mise \
        /usr/local/bin/mise \
        /home/linuxbrew/.linuxbrew/bin/mise \
        "$HOME/.local/bin/mise"; do
        if [[ -x "$candidate" ]]; then
            MISE_BIN="$candidate"
            break
        fi
    done
fi

if [[ -z "$MISE_BIN" ]]; then
    echo "ERROR: mise not found. Install via 'brew install mise' or see https://mise.jdx.dev/getting-started.html" >&2
    exit 1
fi

cd "$TARGET_DIR"

"$MISE_BIN" exec -- terraform init -backend=false -input=false -no-color >/dev/null
exec "$MISE_BIN" exec -- terraform validate -no-color
