#!/bin/bash
set -e

# Install redeploy-on-boot systemd service on EC2 via SSM
# Uploads script + unit, installs on EC2
# The service automatically redeploys the app on boot.

REGION=${REGION:-eu-central-1}
STATE_BUCKET=${STATE_BUCKET:-team7-dev-tf-state}
PREFIX=${PREFIX:-systemd}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DEV_DIR="${SCRIPT_DIR}/../dev"

BASH_SCRIPT="${REPO_ROOT}/infrastructure/scripts/redeploy_on_boot.sh"
UNIT_FILE="${REPO_ROOT}/infrastructure/systemd/redeploy-on-boot.service"

if [ ! -f "$BASH_SCRIPT" ]; then
  echo "❌ ERROR: Missing $BASH_SCRIPT"
  exit 1
fi

if [ ! -f "$UNIT_FILE" ]; then
  echo "❌ ERROR: Missing $UNIT_FILE"
  exit 1
fi

# Get instance ID from Terraform
cd "$DEV_DIR"
INSTANCE_ID=$(terraform output -raw ec2_instance_id)
PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text \
  --region "$REGION")

echo "🖥️  Instance: $INSTANCE_ID"
echo "🌐 Public IP: $PUBLIC_IP"
echo "📤 Uploading files to S3..."

# Upload both files to S3
aws s3 cp "$BASH_SCRIPT" \
  s3://${STATE_BUCKET}/${PREFIX}/redeploy_on_boot.sh \
  --region "$REGION"

aws s3 cp "$UNIT_FILE" \
  s3://${STATE_BUCKET}/${PREFIX}/redeploy-on-boot.service \
  --region "$REGION"

echo "✅ Uploaded to s3://${STATE_BUCKET}/${PREFIX}/"
echo "🚀 Installing service on EC2 via SSM..."

# Build SSM command to install and enable the service
COMMANDS_JSON="[
  \"echo 'Downloading files from S3...'\",
  \"sudo aws s3 cp s3://${STATE_BUCKET}/${PREFIX}/redeploy_on_boot.sh /usr/local/bin/redeploy_on_boot.sh --region ${REGION}\",
  \"sudo chmod +x /usr/local/bin/redeploy_on_boot.sh\",
  \"sudo aws s3 cp s3://${STATE_BUCKET}/${PREFIX}/redeploy-on-boot.service /etc/systemd/system/redeploy-on-boot.service --region ${REGION}\",
  \"sudo chmod 644 /etc/systemd/system/redeploy-on-boot.service\",
  \"echo 'Enabling and starting service...'\",
  \"sudo systemctl daemon-reload\",
  \"sudo systemctl enable redeploy-on-boot.service\",
  \"sudo systemctl start redeploy-on-boot.service || true\",
  \"echo '✅ Installed redeploy-on-boot.service'\",
  \"systemctl status redeploy-on-boot.service --no-pager || true\"
]"

# Execute via SSM
COMMAND_ID=$(aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --document-name "AWS-RunShellScript" \
  --parameters commands="$COMMANDS_JSON" \
  --region "$REGION" \
  --query "Command.CommandId" \
  --output text)

echo "SSM Command ID: $COMMAND_ID"
aws ssm wait command-executed --command-id "$COMMAND_ID" --instance-id "$INSTANCE_ID" --region "$REGION"

STATUS=$(aws ssm get-command-invocation \
  --command-id "$COMMAND_ID" \
  --instance-id "$INSTANCE_ID" \
  --query Status \
  --output text \
  --region "$REGION")

if [ "$STATUS" != "Success" ]; then
  echo "❌ Installation failed: $STATUS"
  aws ssm get-command-invocation \
    --command-id "$COMMAND_ID" \
    --instance-id "$INSTANCE_ID" \
    --query StandardErrorContent \
    --output text \
    --region "$REGION"
  exit 1
fi

echo "✅ Redeploy-on-boot service installed and enabled on $INSTANCE_ID"
echo "• Public IP: $PUBLIC_IP"
echo "• Service: redeploy-on-boot.service (enabled)"