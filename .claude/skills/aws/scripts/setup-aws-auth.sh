#!/usr/bin/env bash
set -euo pipefail

# Set up AWS authentication by exporting the cargonautica profile
# Usage: source .claude/skills/aws/scripts/setup-aws-auth.sh

PROFILE="cargonautica"

# Export the AWS profile
export AWS_PROFILE="$PROFILE"

echo "✓ AWS_PROFILE set to: $PROFILE"

# Check if authentication is valid
if command -v aws &> /dev/null; then
    if aws sts get-caller-identity --profile "$PROFILE" &> /dev/null 2>&1; then
        echo "✓ AWS authentication is valid"

        # Show current identity
        IDENTITY=$(aws sts get-caller-identity --profile "$PROFILE" --output json 2>/dev/null)
        ACCOUNT=$(echo "$IDENTITY" | grep -o '"Account": "[^"]*"' | cut -d'"' -f4)

        echo "  AWS Account: $ACCOUNT"
    else
        echo "⚠ WARNING: AWS authentication check failed" >&2
        echo "  Run: aws sso login --profile $PROFILE" >&2
        return 1
    fi
else
    echo "⚠ WARNING: AWS CLI not found" >&2
    return 1
fi
