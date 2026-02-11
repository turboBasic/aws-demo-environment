#!/usr/bin/env bash
# shellcheck disable=SC2155

# Extract and export temporary AWS credentials from SSO cache
# Usage: source aws-sso-credentials.sh

# The script extracts the SSO access token from `~/.aws/sso/cache/`,
# exchanges it for temporary AWS credentials, and exports them as
# environment variables (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`,
# `AWS_SESSION_TOKEN`).

set -euo pipefail

# SSO configuration
SSO_START_URL="https://cargonautica.awsapps.com/start"
SSO_ROLE_NAME="AdministratorAccess"
SSO_ACCOUNT_ID="381492075850"
SSO_REGION="eu-central-1"

echo "🔐 Extracting AWS credentials from SSO cache..."

# Extract access token from SSO cache
ACCESS_TOKEN=$(cat ~/.aws/sso/cache/*.json 2>/dev/null | \
  jq -r "select(.startUrl == \"$SSO_START_URL\") | .accessToken" | \
  head -1)

if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" == "null" ]; then
  echo "❌ Error: No valid SSO token found in cache"
  echo "   Run: aws sso login --profile cargonautica"
  return 1 2>/dev/null || exit 1
fi

echo "✓ Found SSO access token"

# Get temporary credentials
CREDS=$(aws sso get-role-credentials \
  --role-name "$SSO_ROLE_NAME" \
  --account-id "$SSO_ACCOUNT_ID" \
  --access-token "$ACCESS_TOKEN" \
  --region "$SSO_REGION" 2>/dev/null)

if [ $? -ne 0 ]; then
  echo "❌ Error: Failed to get role credentials"
  echo "   Your SSO session may have expired"
  echo "   Run: aws sso login --profile cargonautica"
  return 1 2>/dev/null || exit 1
fi

# Export credentials as environment variables
export AWS_ACCESS_KEY_ID=$(echo "$CREDS" | jq -r '.roleCredentials.accessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo "$CREDS" | jq -r '.roleCredentials.secretAccessKey')
export AWS_SESSION_TOKEN=$(echo "$CREDS" | jq -r '.roleCredentials.sessionToken')

# Get expiration time
EXPIRATION=$(echo "$CREDS" | jq -r '.roleCredentials.expiration')
EXPIRATION_DATE=$(date -r $((EXPIRATION / 1000)) '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "unknown")

echo "✓ AWS credentials exported to environment"
echo "  Access Key: ${AWS_ACCESS_KEY_ID}"
echo "  Expires at: ${EXPIRATION_DATE}"
echo ""
echo "You can now run AWS CLI and Terraform commands."
