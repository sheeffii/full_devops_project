#!/bin/bash
set -e

# Deploy monitoring stack (Prometheus + Alertmanager + Grafana) on EC2
echo "=== Deploying Monitoring Stack to EC2 ==="

# Discord webhook URL from environment
DISCORD_WEBHOOK_URL="${DISCORD_WEBHOOK_URL:-}"
if [ -z "$DISCORD_WEBHOOK_URL" ]; then
  echo "⚠️  WARNING: DISCORD_WEBHOOK_URL not set - alerts won't be sent to Discord"
fi

# Get EC2 IP from Terraform (robust relative paths)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DEV_DIR="${SCRIPT_DIR}/../dev"
echo "Terraform dev dir: ${DEV_DIR}"
cd "${DEV_DIR}"
INSTANCE_ID=$(terraform output -raw ec2_instance_id)
PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text \
  --region eu-central-1)

echo "EC2 Public IP: $PUBLIC_IP"

# Upload monitoring configs to S3 for EC2 to download
# Reuse existing Terraform backend bucket with a dedicated prefix
STATE_BUCKET="${STATE_BUCKET:-team7-dev-tf-state}"
MONITORING_PREFIX="${MONITORING_PREFIX:-monitoring}"

echo "Using S3 bucket: ${STATE_BUCKET} (prefix: ${MONITORING_PREFIX}/)"

# Resolve asset paths at repo root
PROMETHEUS_CONFIG_PATH="${REPO_ROOT}/infrastructure/monitoring/configs/prometheus.yml"
ALERT_RULES_PATH="${REPO_ROOT}/infrastructure/monitoring/configs/alert.rules.yml"
ALERTMANAGER_CONFIG_PATH="${REPO_ROOT}/infrastructure/monitoring/configs/alertmanager.yml"
DISCORD_PROXY_PATH="${REPO_ROOT}/infrastructure/scripts/discord-webhook-proxy.py"
GRAFANA_PROVISIONING_DIR="${REPO_ROOT}/infrastructure/monitoring/grafana-provisioning"
GRAFANA_DASHBOARDS_DIR="${REPO_ROOT}/infrastructure/monitoring/grafana-dashboards"

echo "Repo root: ${REPO_ROOT}"
echo "Prometheus config: ${PROMETHEUS_CONFIG_PATH}"
echo "Alert rules: ${ALERT_RULES_PATH}"
echo "Alertmanager config: ${ALERTMANAGER_CONFIG_PATH}"
echo "Discord proxy: ${DISCORD_PROXY_PATH}"
echo "Grafana provisioning: ${GRAFANA_PROVISIONING_DIR}"
echo "Grafana dashboards: ${GRAFANA_DASHBOARDS_DIR}"

# Upload prometheus.yml
if [ -f "${PROMETHEUS_CONFIG_PATH}" ]; then
  aws s3 cp "${PROMETHEUS_CONFIG_PATH}" s3://${STATE_BUCKET}/${MONITORING_PREFIX}/prometheus.yml
else
  echo "⚠️  prometheus.yml not found — continuing without Prometheus config"
fi

# Upload alert rules if present
if [ -f "${ALERT_RULES_PATH}" ]; then
  aws s3 cp "${ALERT_RULES_PATH}" s3://${STATE_BUCKET}/${MONITORING_PREFIX}/alert.rules.yml
else
  echo "⚠️  alert.rules.yml not found — continuing without alert rules"
fi

# Upload alertmanager config if present
if [ -f "${ALERTMANAGER_CONFIG_PATH}" ]; then
  aws s3 cp "${ALERTMANAGER_CONFIG_PATH}" s3://${STATE_BUCKET}/${MONITORING_PREFIX}/alertmanager.yml
else
  echo "⚠️  alertmanager.yml not found — continuing without alertmanager"
fi

# Upload Discord webhook proxy script
if [ -f "${DISCORD_PROXY_PATH}" ]; then
  aws s3 cp "${DISCORD_PROXY_PATH}" s3://${STATE_BUCKET}/${MONITORING_PREFIX}/discord-webhook-proxy.py
else
  echo "⚠️  discord-webhook-proxy.py not found — alerts won't be sent to Discord"
fi

# Upload Grafana provisioning configs (datasource + dashboard provider)
if [ -d "${GRAFANA_PROVISIONING_DIR}" ]; then
  aws s3 cp "${GRAFANA_PROVISIONING_DIR}" s3://${STATE_BUCKET}/${MONITORING_PREFIX}/grafana-provisioning/ --recursive
else
  echo "⚠️  grafana-provisioning/ not found — Grafana will start without auto-provisioned datasources"
fi

# Upload dashboards if present
if [ -d "${GRAFANA_DASHBOARDS_DIR}" ]; then
  aws s3 cp "${GRAFANA_DASHBOARDS_DIR}" s3://${STATE_BUCKET}/${MONITORING_PREFIX}/grafana-dashboards/ --recursive
else
  echo "⚠️  grafana-dashboards/ not found — no dashboards will be uploaded"
fi

# Define commands as a JSON array (fix for AWS CLI parsing)
COMMANDS_JSON='[
  "# Download monitoring configs from S3",
  "sudo mkdir -p /opt/monitoring/{prometheus,alertmanager,grafana-provisioning,grafana-dashboards}",
  "aws s3 cp s3://'${STATE_BUCKET}'/'${MONITORING_PREFIX}'/prometheus.yml /opt/monitoring/prometheus/prometheus.yml",
  "aws s3 cp s3://'${STATE_BUCKET}'/'${MONITORING_PREFIX}'/alert.rules.yml /opt/monitoring/prometheus/alert.rules.yml || true",
  "aws s3 cp s3://'${STATE_BUCKET}'/'${MONITORING_PREFIX}'/alertmanager.yml /opt/monitoring/alertmanager/alertmanager.yml || true",
  "aws s3 cp s3://'${STATE_BUCKET}'/'${MONITORING_PREFIX}'/discord-webhook-proxy.py /opt/monitoring/discord-webhook-proxy.py || true",
  "aws s3 cp s3://'${STATE_BUCKET}'/'${MONITORING_PREFIX}'/grafana-provisioning/ /opt/monitoring/grafana-provisioning/ --recursive || true",
  "aws s3 cp s3://'${STATE_BUCKET}'/'${MONITORING_PREFIX}'/grafana-dashboards/ /opt/monitoring/grafana-dashboards/ --recursive || true",
  "sudo chmod -R u=rwX,go=rX /opt/monitoring/",
  "sudo chmod +x /opt/monitoring/discord-webhook-proxy.py || true",
  "# Create Docker network for monitoring",
  "sudo docker network create monitoring 2>/dev/null || true",
  "# Ensure node-exporter (dockerized)",
  "sudo docker stop node-exporter 2>/dev/null || true",
  "sudo docker rm node-exporter 2>/dev/null || true",
  "sudo docker run -d --name node-exporter --restart unless-stopped --network monitoring -p 9100:9100 -v /:/host:ro,rslave quay.io/prometheus/node-exporter:latest --path.rootfs=/host",
  "# Ensure cAdvisor",
  "sudo docker stop cadvisor 2>/dev/null || true",
  "sudo docker rm cadvisor 2>/dev/null || true",
  "sudo docker run -d --name cadvisor --restart unless-stopped --network monitoring -p 8080:8080 --volume=/:/rootfs:ro --volume=/var/run:/var/run:rw --volume=/sys:/sys:ro --volume=/var/lib/docker/:/var/lib/docker:ro --volume=/dev/disk/:/dev/disk:ro --privileged gcr.io/cadvisor/cadvisor:latest",
  "sleep 2",
  "if ! sudo docker ps | grep -q cadvisor; then echo ERROR: cAdvisor failed to start; sudo docker logs cadvisor 2>&1 || true; fi",
  "# Deploy Discord Webhook Proxy (if webhook URL provided)",
  "if [ -n '\"'\"'${DISCORD_WEBHOOK_URL}'\"'\"' ] && [ -f /opt/monitoring/discord-webhook-proxy.py ]; then sudo docker stop discord-proxy 2>/dev/null || true; sudo docker rm discord-proxy 2>/dev/null || true; sudo docker run -d --name discord-proxy --restart unless-stopped --network monitoring -p 9094:9094 -v /opt/monitoring:/app:ro -e DISCORD_WEBHOOK_URL='\"'\"'${DISCORD_WEBHOOK_URL}'\"'\"' python:3.11-slim sh -c '\"'\"'pip install --quiet --no-cache-dir requests && python /app/discord-webhook-proxy.py'\"'\"'; else echo '\"'\"'Skipping Discord proxy (no webhook URL or script missing)'\"'\"'; fi",
  "# Deploy Alertmanager",
  "sudo docker stop alertmanager 2>/dev/null || true",
  "sudo docker rm alertmanager 2>/dev/null || true",
  "sudo docker run -d --name alertmanager --restart unless-stopped --network monitoring -p 9093:9093 -v /opt/monitoring/alertmanager:/etc/alertmanager:ro prom/alertmanager:latest --config.file=/etc/alertmanager/alertmanager.yml",
  "# Deploy Prometheus",
  "sudo docker stop prometheus 2>/dev/null || true",
  "sudo docker rm prometheus 2>/dev/null || true",
  "sudo docker run -d --name prometheus --restart unless-stopped --network monitoring -p 9090:9090 -v /opt/monitoring/prometheus:/etc/prometheus:ro prom/prometheus:latest --config.file=/etc/prometheus/prometheus.yml --web.enable-lifecycle",
  "# Deploy Grafana",
  "sudo docker stop grafana 2>/dev/null || true",
  "sudo docker rm grafana 2>/dev/null || true",
  "sudo docker run -d --name grafana --restart unless-stopped --network monitoring -p 3000:3000 -e GF_SECURITY_ADMIN_PASSWORD=admin -e GF_USERS_ALLOW_SIGN_UP=false -v /opt/monitoring/grafana-provisioning:/etc/grafana/provisioning:ro -v /opt/monitoring/grafana-dashboards:/var/lib/grafana/dashboards:ro grafana/grafana:latest",
  "echo \"Monitoring stack deployed successfully!\"",
  "echo \"Prometheus: http://'${PUBLIC_IP}':9090\"",
  "echo \"Alertmanager: http://'${PUBLIC_IP}':9093\"",
  "echo \"Grafana: http://'${PUBLIC_IP}':3000 (admin/admin)\""
]'

# Deploy monitoring stack via SSM
COMMAND_ID=$(aws ssm send-command \
  --instance-ids "${INSTANCE_ID}" \
  --document-name "AWS-RunShellScript" \
  --parameters "commands=${COMMANDS_JSON}" \
  --region eu-central-1 \
  --query "Command.CommandId" \
  --output text)

echo "Command ID: $COMMAND_ID"
echo "Waiting for deployment..."

aws ssm wait command-executed \
  --command-id $COMMAND_ID \
  --instance-id $INSTANCE_ID \
  --region eu-central-1

STATUS=$(aws ssm get-command-invocation \
  --command-id $COMMAND_ID \
  --instance-id $INSTANCE_ID \
  --query "Status" \
  --output text \
  --region eu-central-1)

if [ "$STATUS" != "Success" ]; then
  echo "❌ Monitoring deployment failed: $STATUS"
  aws ssm get-command-invocation \
    --command-id $COMMAND_ID \
    --instance-id $INSTANCE_ID \
    --query "StandardErrorContent" \
    --output text \
    --region eu-central-1
  exit 1
fi

echo "✅ Monitoring stack deployed successfully!"
echo ""
echo "Access your monitoring:"
echo "  Prometheus:    http://$PUBLIC_IP:9090"
echo "  Alertmanager:  http://$PUBLIC_IP:9093"
echo "  Grafana:       http://$PUBLIC_IP:3000 (admin/admin)"
echo "  Node Exporter: http://$PUBLIC_IP:9100/metrics"
echo "  cAdvisor:      http://$PUBLIC_IP:8080"