#!/usr/bin/env bash
set -euo pipefail

# Find terraform executable in various installation locations
# Returns the path to terraform or exits with error

# 1. Check if terraform is in PATH
if command -v terraform &> /dev/null; then
    which terraform
    exit 0
fi

# 2. Check mise installations
MISE_TERRAFORM_DIR="$HOME/.local/share/mise/installs/terraform"
if [[ -d "$MISE_TERRAFORM_DIR" ]]; then
    # Find the newest version or 'latest' symlink
    MISE_BIN=$(find "$MISE_TERRAFORM_DIR" -type f -name terraform -path "*/bin/terraform" 2>/dev/null | head -n 1)
    if [[ -n "$MISE_BIN" && -x "$MISE_BIN" ]]; then
        echo "$MISE_BIN"
        exit 0
    fi
fi

# 3. Check tfenv installation
TFENV_BIN="$HOME/.tfenv/bin/terraform"
if [[ -x "$TFENV_BIN" ]]; then
    echo "$TFENV_BIN"
    exit 0
fi

# 4. Check asdf installation
ASDF_TERRAFORM_DIR="$HOME/.asdf/installs/terraform"
if [[ -d "$ASDF_TERRAFORM_DIR" ]]; then
    ASDF_BIN=$(find "$ASDF_TERRAFORM_DIR" -type f -name terraform -path "*/bin/terraform" 2>/dev/null | head -n 1)
    if [[ -n "$ASDF_BIN" && -x "$ASDF_BIN" ]]; then
        echo "$ASDF_BIN"
        exit 0
    fi
fi

# 5. Check Homebrew installation (macOS)
if [[ "$(uname)" == "Darwin" ]]; then
    BREW_PREFIX=$(brew --prefix 2>/dev/null || echo "/usr/local")
    BREW_BIN="$BREW_PREFIX/bin/terraform"
    if [[ -x "$BREW_BIN" ]]; then
        echo "$BREW_BIN"
        exit 0
    fi
fi

# Not found
echo "ERROR: terraform executable not found. Please install terraform." >&2
exit 1
