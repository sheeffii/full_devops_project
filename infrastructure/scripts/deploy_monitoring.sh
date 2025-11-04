#!/bin/bash
set -e

# Deploy monitoring stack (Prometheus + Grafana) on EC2
echo "=== Deploying Monitoring Stack to EC2 ==="

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

# Create prometheus.yml with EC2 IP
cat > /tmp/prometheus.yml <<EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - '/etc/prometheus/alert.rules.yml'

scrape_configs:
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['localhost:9100']
        labels:
          instance: 'ec2-node'
          environment: 'production'

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['localhost:8080']
        labels:
          instance: 'ec2-cadvisor'
          environment: 'production'

  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
EOF

# Upload monitoring configs to S3 for EC2 to download
# Reuse existing Terraform backend bucket with a dedicated prefix
STATE_BUCKET="${STATE_BUCKET:-team7-dev-tf-state}"
MONITORING_PREFIX="${MONITORING_PREFIX:-monitoring}"

echo "Using S3 bucket: ${STATE_BUCKET} (prefix: ${MONITORING_PREFIX}/)"

# Resolve asset paths at repo root
ALERT_RULES_PATH="${REPO_ROOT}/alert.rules.yml"
GRAFANA_PROVISIONING_DIR="${REPO_ROOT}/grafana-provisioning"
GRAFANA_DASHBOARDS_DIR="${REPO_ROOT}/grafana-dashboards"

echo "Repo root: ${REPO_ROOT}"
echo "Alert rules: ${ALERT_RULES_PATH}"
echo "Grafana provisioning: ${GRAFANA_PROVISIONING_DIR}"
echo "Grafana dashboards: ${GRAFANA_DASHBOARDS_DIR}"

# Upload prometheus.yml (always generated)
aws s3 cp /tmp/prometheus.yml s3://${STATE_BUCKET}/${MONITORING_PREFIX}/prometheus.yml

# Upload alert rules if present
if [ -f "${ALERT_RULES_PATH}" ]; then
  aws s3 cp "${ALERT_RULES_PATH}" s3://${STATE_BUCKET}/${MONITORING_PREFIX}/alert.rules.yml
else
  echo "⚠️  alert.rules.yml not found — continuing without alert rules"
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

# Deploy monitoring stack via SSM
COMMAND_ID=$(aws ssm send-command \
  --instance-ids $INSTANCE_ID \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=[
    "# Download monitoring configs from S3",
    "sudo mkdir -p /opt/monitoring/{prometheus,grafana-provisioning,grafana-dashboards}",
  "aws s3 cp s3://'${STATE_BUCKET}'/'${MONITORING_PREFIX}'/prometheus.yml /opt/monitoring/prometheus/prometheus.yml",
  "aws s3 cp s3://'${STATE_BUCKET}'/'${MONITORING_PREFIX}'/alert.rules.yml /opt/monitoring/prometheus/alert.rules.yml",
  "aws s3 cp s3://'${STATE_BUCKET}'/'${MONITORING_PREFIX}'/grafana-provisioning/ /opt/monitoring/grafana-provisioning/ --recursive || true",
  "aws s3 cp s3://'${STATE_BUCKET}'/'${MONITORING_PREFIX}'/grafana-dashboards/ /opt/monitoring/grafana-dashboards/ --recursive || true",
    "sudo chmod -R 644 /opt/monitoring/",
    "",
    "# Create Docker network for monitoring",
    "sudo docker network create monitoring 2>/dev/null || true",
    "",
    "# Deploy Prometheus",
    "sudo docker stop prometheus 2>/dev/null || true",
    "sudo docker rm prometheus 2>/dev/null || true",
    "sudo docker run -d \\",
    "  --name prometheus \\",
    "  --restart unless-stopped \\",
    "  --network monitoring \\",
    "  -p 9090:9090 \\",
    "  -v /opt/monitoring/prometheus:/etc/prometheus:ro \\",
    "  prom/prometheus:latest \\",
    "  --config.file=/etc/prometheus/prometheus.yml \\",
    "  --web.enable-lifecycle",
    "",
    "# Deploy Grafana",
    "sudo docker stop grafana 2>/dev/null || true",
    "sudo docker rm grafana 2>/dev/null || true",
    "sudo docker run -d \\",
    "  --name grafana \\",
    "  --restart unless-stopped \\",
    "  --network monitoring \\",
    "  -p 3000:3000 \\",
    "  -e GF_SECURITY_ADMIN_PASSWORD=admin \\",
    "  -e GF_USERS_ALLOW_SIGN_UP=false \\",
    "  -v /opt/monitoring/grafana-provisioning:/etc/grafana/provisioning:ro \\",
    "  -v /opt/monitoring/grafana-dashboards:/var/lib/grafana/dashboards:ro \\",
    "  grafana/grafana:latest",
    "",
    "echo \"Monitoring stack deployed successfully!\"",
    "echo \"Prometheus: http://'$PUBLIC_IP':9090\"",
    "echo \"Grafana: http://'$PUBLIC_IP':3000 (admin/admin)\""
  ]' \
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
echo "  Prometheus: http://$PUBLIC_IP:9090"
echo "  Grafana:    http://$PUBLIC_IP:3000 (admin/admin)"
echo "  Node Exporter: http://$PUBLIC_IP:9100/metrics"
echo "  cAdvisor:   http://$PUBLIC_IP:8080"
