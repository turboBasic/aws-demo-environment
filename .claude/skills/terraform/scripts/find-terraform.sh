#!/usr/bin/env bash

if command -v terraform &> /dev/null; then
    echo "terraform"
else
    # Fall back to full path
    echo "$HOME"/.local/share/mise/installs/terraform/latest/terraform
fi
