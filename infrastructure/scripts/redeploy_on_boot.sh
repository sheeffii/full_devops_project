#!/bin/bash
# Redeploy team7 app from ECR and ensure monitoring is running

set -euo pipefail

AWS_REGION="eu-central-1"
ECR_REPO="team7-app"

log() { echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] $*"; }

log "Getting AWS account ID..."
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
IMAGE_REF="${ECR_REGISTRY}/${ECR_REPO}:latest"

log "Logging into ECR..."
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY"

log "Pulling latest image..."
docker pull "$IMAGE_REF" >/dev/null

# Determine currently running image ID (if container exists)
CURRENT_IMAGE_ID=""
if docker inspect team7-app >/dev/null 2>&1; then
  CURRENT_IMAGE_ID=$(docker inspect --format '{{.Image}}' team7-app || true)
fi

# Determine newly pulled image ID
NEW_IMAGE_ID=$(docker inspect --format '{{.Id}}' "$IMAGE_REF")

if [[ -n "$CURRENT_IMAGE_ID" && "$CURRENT_IMAGE_ID" == "$NEW_IMAGE_ID" ]]; then
  log "Image unchanged (${NEW_IMAGE_ID}). Skipping app restart."
else
  log "Image changed (current: ${CURRENT_IMAGE_ID:-none}, new: ${NEW_IMAGE_ID}). Restarting app container..."
  docker stop team7-app 2>/dev/null || true
  docker rm team7-app 2>/dev/null || true

  log "Starting new app container..."
  docker run -d \
    --name team7-app \
    -p 80:3000 \
    --restart unless-stopped \
    "$IMAGE_REF"
fi

log "Ensuring monitoring containers are running (if present)..."
docker start prometheus grafana node-exporter cadvisor 2>/dev/null || true

log "Redeploy complete!"
