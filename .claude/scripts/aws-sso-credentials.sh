#!/usr/bin/env bash
#
# Extract and export temporary AWS credentials from SSO cache
#
# Usage:
#   source aws-sso-credentials.sh
#
# Description:
#   Extracts the SSO access token from ~/.aws/sso/cache/, exchanges it for
#   temporary AWS credentials, and exports them as environment variables
#   (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN).
#
# Example:
#   source .claude/scripts/aws-sso-credentials.sh
#

asc_main() {
  local sso_start_url="https://cargonautica.awsapps.com/start"
  local sso_role_name="AdministratorAccess"
  local sso_account_id="381492075850"
  local sso_region="eu-central-1"

  echo "🔐 Extracting AWS credentials from SSO cache..."

  local access_token
  access_token=$(asc_extract_access_token "$sso_start_url") || return 1

  echo "✓ Found SSO access token"

  local creds
  creds=$(asc_get_role_credentials "$sso_role_name" "$sso_account_id" "$access_token" "$sso_region") || return 1

  asc_export_credentials "$creds"
}

asc_extract_access_token() {
  local sso_start_url="$1"
  local access_token

  access_token=$(cat ~/.aws/sso/cache/*.json 2>/dev/null | \
    jq -r "select(.startUrl == \"$sso_start_url\") | .accessToken" | \
    head -1)

  if [[ -z "$access_token" ]] || [[ "$access_token" == "null" ]]; then
    echo "❌ Error: No valid SSO token found in cache" >&2
    echo "   Run: aws sso login --profile Cargonautica" >&2
    return 1
  fi

  echo "$access_token"
}

asc_get_role_credentials() {
  local sso_role_name="$1"
  local sso_account_id="$2"
  local access_token="$3"
  local sso_region="$4"
  local creds

  creds=$(aws sso get-role-credentials \
    --role-name "$sso_role_name" \
    --account-id "$sso_account_id" \
    --access-token "$access_token" \
    --region "$sso_region" 2>/dev/null) || {
    echo "❌ Error: Failed to get role credentials" >&2
    echo "   Your SSO session may have expired" >&2
    echo "   Run: aws sso login --profile Cargonautica" >&2
    return 1
  }

  echo "$creds"
}

asc_export_credentials() {
  local creds="$1"
  local aws_access_key_id
  local aws_secret_access_key
  local aws_session_token

  aws_access_key_id=$(echo "$creds" | jq -r '.roleCredentials.accessKeyId')
  aws_secret_access_key=$(echo "$creds" | jq -r '.roleCredentials.secretAccessKey')
  aws_session_token=$(echo "$creds" | jq -r '.roleCredentials.sessionToken')

  export AWS_ACCESS_KEY_ID="$aws_access_key_id"
  export AWS_SECRET_ACCESS_KEY="$aws_secret_access_key"
  export AWS_SESSION_TOKEN="$aws_session_token"

  local expiration
  expiration=$(echo "$creds" | jq -r '.roleCredentials.expiration')
  local expiration_date
  expiration_date=$(date -r $((expiration / 1000)) '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "unknown")

  echo "✓ AWS credentials exported to environment"
  echo "  Access Key: ${AWS_ACCESS_KEY_ID}"
  echo "  Expires at: ${expiration_date}"
  echo ""
  echo "You can now run AWS CLI and Terraform commands."
}

asc_main "$@"
_asc_rc=$?
unset -f asc_main asc_extract_access_token asc_get_role_credentials asc_export_credentials
return "$_asc_rc"
