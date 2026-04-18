#!/usr/bin/env bash
#
# Check if AWS authentication is valid for the specified profile.
#
# Usage:
#   ./check-aws-auth.sh
#
# Environment:
#   AWS_PROFILE   Profile name (default: Cargonautica)
#
# Exit codes:
#   0   Authentication valid
#   1   Authentication invalid or missing AWS CLI
#

set -euo pipefail

main() {
  local profile="${AWS_PROFILE:-Cargonautica}"

  check_aws_cli_installed
  verify_authentication "$profile"
  display_identity "$profile"
}

check_aws_cli_installed() {
  if ! command -v aws &> /dev/null; then
    echo "ERROR: AWS CLI not found. Please install AWS CLI." >&2
    exit 1
  fi
}

verify_authentication() {
  local profile="$1"
  if ! aws sts get-caller-identity --profile "$profile" &> /dev/null; then
    echo "ERROR: AWS authentication failed for profile: $profile" >&2
    echo "  Possible causes:" >&2
    echo "    - SSO session expired (run: aws sso login --profile $profile)" >&2
    echo "    - Invalid credentials" >&2
    echo "    - Profile not configured" >&2
    exit 1
  fi
}

display_identity() {
  local profile="$1"
  local identity account arn

  echo "✓ AWS authentication is valid for profile: $profile"

  identity=$(aws sts get-caller-identity --profile "$profile" --output json 2>/dev/null)
  account=$(echo "$identity" | grep -o '"Account": "[^"]*"' | cut -d'"' -f4)
  arn=$(echo "$identity" | grep -o '"Arn": "[^"]*"' | cut -d'"' -f4)

  echo "  Account: $account"
  echo "  Identity: $arn"
}

main "$@"
