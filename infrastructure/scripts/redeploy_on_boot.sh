#!/bin/bash
# Redeploy team7 app from ECR and ensure monitoring is running

set -e

AWS_REGION="eu-central-1"
ECR_REPO="team7-app"

echo "Getting AWS account ID..."
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo "Logging into ECR..."
aws ecr get-login-password --region "$AWS_REGION" | \
  docker login --username AWS --password-stdin "$ECR_REGISTRY"

echo "Pulling latest image..."
docker pull "${ECR_REGISTRY}/${ECR_REPO}:latest"

echo "Stopping old app container..."
docker stop team7-app 2>/dev/null || true
docker rm team7-app 2>/dev/null || true

echo "Starting new app container..."
docker run -d \
  --name team7-app \
  -p 80:3000 \
  --restart unless-stopped \
  "${ECR_REGISTRY}/${ECR_REPO}:latest"

echo "Ensuring monitoring containers are running..."
docker start prometheus grafana node-exporter cadvisor 2>/dev/null || true

echo "Redeploy complete!"
