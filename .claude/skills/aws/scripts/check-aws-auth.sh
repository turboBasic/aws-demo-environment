#!/usr/bin/env bash
set -euo pipefail

# Check if AWS authentication is valid for the cargonautica profile
# Returns 0 if valid, 1 if invalid/expired

PROFILE="${AWS_PROFILE:-cargonautica}"

# Check if AWS CLI is available
if ! command -v aws &> /dev/null; then
    echo "ERROR: AWS CLI not found. Please install AWS CLI." >&2
    exit 1
fi

# Try to get caller identity
if aws sts get-caller-identity --profile "$PROFILE" &> /dev/null; then
    echo "✓ AWS authentication is valid for profile: $PROFILE"

    # Show current identity
    IDENTITY=$(aws sts get-caller-identity --profile "$PROFILE" --output json 2>/dev/null)
    ACCOUNT=$(echo "$IDENTITY" | grep -o '"Account": "[^"]*"' | cut -d'"' -f4)
    ARN=$(echo "$IDENTITY" | grep -o '"Arn": "[^"]*"' | cut -d'"' -f4)

    echo "  Account: $ACCOUNT"
    echo "  Identity: $ARN"
    exit 0
else
    echo "ERROR: AWS authentication failed for profile: $PROFILE" >&2
    echo "  Possible causes:" >&2
    echo "    - SSO session expired (run: aws sso login --profile $PROFILE)" >&2
    echo "    - Invalid credentials" >&2
    echo "    - Profile not configured" >&2
    exit 1
fi
