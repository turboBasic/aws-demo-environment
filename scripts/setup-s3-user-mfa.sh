#!/bin/bash

# cspell:words otpauth TOTP zbarimg
# shellcheck disable=SC2250,SC2162

################################################################################
# Setup MFA for s3-user and save credentials to 1Password
################################################################################
#
# This script registers a virtual MFA device for the s3-user IAM account
# and stores the credentials and MFA seed in 1Password.
#
# Prerequisites:
#   - AWS credentials must be configured with appropriate permissions to manage
#     IAM users and devices
#   - 1Password CLI must be installed and authenticated
#   - Homebrew, 1Password CLI, jq must be installed
#
# Usage:
#   ./setup-s3-user-mfa.sh [--vault VAULT_NAME] [--cleanup]
#
# Options:
#   --vault     1Password vault name (default: "Personal")
#   --cleanup   Remove local temporary files after setup
#
# Example:
#   ./setup-s3-user-mfa.sh --vault "AWS" --cleanup
#

set -euo pipefail

# Configuration
IAM_USER_NAME="s3-user"
IAM_ROLE_NAME=""
VAULT_NAME="${1:-Personal}"
CLEANUP=false
TEMP_DIR=$(mktemp -d)
DEVICE_NAME=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --vault)
      VAULT_NAME="$2"
      shift 2
      ;;
    --user)
      IAM_USER_NAME="$2"
      shift 2
      ;;
    --cleanup)
      CLEANUP=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

IAM_ROLE_NAME="S3AccessRole-generic-storage-$IAM_USER_NAME"
DEVICE_NAME="$IAM_USER_NAME-mfa"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

cleanup() {
  if [[ "$CLEANUP" == true ]]; then
    rm -rf "$TEMP_DIR"
  fi
}

trap cleanup EXIT

echo -e "${BLUE}=== S3 User MFA Setup ===${NC}\n"

# Step 1: Create virtual MFA device
echo -e "${YELLOW}Step 1: Creating virtual MFA device...${NC}"
MFA_RESPONSE=$(aws iam create-virtual-mfa-device \
  --virtual-mfa-device-name "$DEVICE_NAME" \
  --outfile "$TEMP_DIR/mfa_device.png" \
  --bootstrap-method QRCodePNG \
  2>&1 || true)

MFA_SERIAL=$(echo "$MFA_RESPONSE" | jq -r '.VirtualMFADevice.SerialNumber' 2>/dev/null || echo "")

if [[ -z "$MFA_SERIAL" || "$MFA_SERIAL" == "null" ]]; then
  # Device might already exist, try to get it
  MFA_SERIAL=$(aws iam list-virtual-mfa-devices \
    --query "VirtualMFADevices[?SerialNumber!=null && contains(SerialNumber, '${DEVICE_NAME}')].SerialNumber | [0]" \
    --output text)

  if [[ -z "$MFA_SERIAL" || "$MFA_SERIAL" == "None" ]]; then
    echo -e "${RED}Error: Failed to create or find MFA device${NC}"
    exit 1
  fi
  echo -e "${GREEN}Using existing MFA device: $MFA_SERIAL${NC}"
else
  echo -e "${GREEN}MFA device created: $MFA_SERIAL${NC}"
  echo -e "${BLUE}QR code saved to: $TEMP_DIR/mfa_device.png${NC}"
fi

# Step 2: Get the base32 seed from QR code
echo -e "\n${YELLOW}Step 2: Extracting MFA seed from QR code...${NC}"

# Install zbar if needed (macOS with Homebrew)
if ! command -v zbarimg &> /dev/null; then
  echo -e "${YELLOW}Installing zbar for QR code reading...${NC}"
  if command -v brew &> /dev/null; then
    brew install zbar
  else
    echo -e "${RED}Error: zbar not installed. Please install it manually.${NC}"
    echo "macOS: brew install zbar"
    echo "Ubuntu/Debian: sudo apt-get install zbar-tools"
    exit 1
  fi
fi

# Extract MFA seed from QR code (format: otpauth://totp/...?secret=BASE32SEED)
MFA_TEXT=$(zbarimg "$TEMP_DIR/mfa_device.png" 2>/dev/null || echo "")
MFA_SEED=$(grep -oP 'secret=\K[A-Z2-7]+' <<< "$MFA_TEXT" || echo "")
MFA_OTP_URL=$(grep -oP 'otpauth://.+' <<< "$MFA_TEXT" || echo "")

if [[ -z "$MFA_SEED" ]]; then
  echo -e "${YELLOW}Warning: Could not extract seed from QR code automatically${NC}"
  echo -e "${BLUE}You can manually extract the seed from the QR code:${NC}"
  echo -e "  - Scan: $TEMP_DIR/mfa_device.png"
  echo -e "  - Or use: zbarimg $TEMP_DIR/mfa_device.png"
  MFA_SEED=""
fi

# Step 3: Get access key from Terraform output
echo -e "\n${YELLOW}Step 3: Retrieving s3-user credentials from Terraform...${NC}"
ACCESS_KEY_ID=$(terraform output -raw generic_storage_access_key_id 2>/dev/null || echo "")
SECRET_ACCESS_KEY=$(terraform output -raw generic_storage_secret_access_key 2>/dev/null || echo "")

if [[ -z "$ACCESS_KEY_ID" || -z "$SECRET_ACCESS_KEY" ]]; then
  echo -e "${RED}Error: Could not retrieve Terraform outputs${NC}"
  echo "Make sure generic_storage module outputs are defined in outputs.tf"
  exit 1
fi

echo -e "${GREEN}Credentials retrieved from Terraform outputs${NC}"

# Step 4: Create 1Password item
echo -e "\n${YELLOW}Step 4: Saving credentials to 1Password...${NC}"

if ! command -v op &> /dev/null; then
  echo -e "${YELLOW}Warning: 1Password CLI not found. Please install it first.${NC}"
  exit 1
fi

echo -e "${YELLOW}Creating 1Password item...${NC}"
op item create \
  --vault "$VAULT_NAME" \
  --category login \
  --title "com.amazon.aws@cargonautica@$IAM_USER_NAME" \
  --url https://console.aws.amazon.com \
  --tags aws,cargonautica \
  "username=$IAM_USER_NAME" \
  "Security.access-key-id[password]=$ACCESS_KEY_ID" \
  "Security.secret-access-key[password]=$SECRET_ACCESS_KEY" \
  "one-time-password[otp]=$MFA_OTP_URL" \
|| {
  echo -e "${RED}Error: Failed to create 1Password item${NC}"
  exit 1
}
echo -e "${GREEN}Item created in 1Password${NC}"

# Step 5: Prompt for MFA codes and enable MFA
echo -e "\n${YELLOW}Step 5: Enabling MFA device...${NC}"
echo -e "${BLUE}To complete MFA registration, you need two 6-digit codes from your authenticator.${NC}"
echo "If you added the device to 1Password, open 1Password and look for the OTP code for com.amazon.aws@cargonautica@$IAM_USER_NAME."
echo ""

read -p "Enter first MFA authentication code (6 digits): " MFA_CODE1
read -p "Enter second MFA authentication code (6 digits): " MFA_CODE2

# Enable MFA device
if aws iam enable-mfa-device \
  --user-name "$IAM_USER_NAME" \
  --serial-number "$MFA_SERIAL" \
  --authentication-code1 "$MFA_CODE1" \
  --authentication-code2 "$MFA_CODE2" 2>/dev/null; then
  echo -e "${GREEN}MFA device enabled successfully${NC}"
else
  echo -e "${RED}Error: Failed to enable MFA device${NC}"
  echo "Verify the codes are correct and try again."
  exit 1
fi

# Step 6: Display next steps
echo -e "\n${GREEN}=== MFA Setup Complete ===${NC}\n"
echo -e "${BLUE}Summary:${NC}"
echo "  • IAM User: $IAM_USER_NAME"
echo "  • MFA Device: $MFA_SERIAL"
echo "  • Role: $IAM_ROLE_NAME"
echo "  • 1Password Vault: $VAULT_NAME"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "1. Configure AWS CLI to use MFA:"
echo "   Set AWS_PROFILE environment variable to include MFA in your CLI config"
echo ""
echo "2. To assume the S3 role with MFA, use:"
echo "   aws sts assume-role --role-arn arn:aws:iam::\$(aws sts get-caller-identity --query Account --output text):role/$IAM_ROLE_NAME --role-session-name s3-session --serial-number $MFA_SERIAL --token-code <6-digit code>"
echo ""
echo "3. Test the setup:"
echo "   aws s3 ls s3://<bucket_name>-<account_id> --profile s3-user-mfa"
echo ""

if [[ "$CLEANUP" != true ]]; then
  echo -e "${YELLOW}Note: QR code and temporary files saved in: $TEMP_DIR${NC}"
  echo "Run with --cleanup flag to remove them automatically"
fi
