#!/usr/bin/env bash
#
# Set up AWS authentication by exporting the cargonautica profile.
#
# Usage:
#   source .claude/skills/aws/scripts/setup-aws-auth.sh
#
# Effects:
#   - Exports AWS_PROFILE=Cargonautica
#   - Verifies authentication and displays account info
#   - Returns 1 if AWS CLI missing or authentication failed
#

saa_main() {
  local profile="Cargonautica"

  saa_export_profile "$profile"
  saa_check_aws_cli_installed
  saa_verify_authentication "$profile" || return 1
  saa_display_account "$profile"
}

saa_export_profile() {
  local profile="$1"
  export AWS_PROFILE="$profile"
  echo "✓ AWS_PROFILE set to: $profile"
}

saa_check_aws_cli_installed() {
  if ! command -v aws &> /dev/null; then
    echo "⚠ WARNING: AWS CLI not found" >&2
    return 1
  fi
}

saa_verify_authentication() {
  local profile="$1"
  if ! aws sts get-caller-identity --profile "$profile" &> /dev/null 2>&1; then
    echo "⚠ WARNING: AWS authentication check failed" >&2
    echo "  Run: aws sso login --profile $profile" >&2
    aws sso login --profile "$profile"
  fi
}

saa_display_account() {
  local profile="$1"
  local identity account

  echo "✓ AWS authentication is valid"

  identity=$(aws sts get-caller-identity --profile "$profile" --output json 2>/dev/null)
  account=$(echo "$identity" | grep -o '"Account": "[^"]*"' | cut -d'"' -f4)

  echo "✓ AWS Account: $account"
}

saa_main "$@"
_saa_rc=$?
unset -f saa_main saa_export_profile saa_check_aws_cli_installed saa_verify_authentication saa_display_account
return "$_saa_rc"
