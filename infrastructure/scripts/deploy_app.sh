#!/bin/bash
set -e

# THIS IS OPTIONAL BECAUSE WE ARE USING THE ECR REGISTRY IN THE GITHUB ACTIONS WORKFLOW
# Get AWS account ID dynamically
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="eu-central-1"
ECR_REPO="team7-app"

# Get the ECR auth token and login
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

# Pull and run the latest app image
docker pull ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}:latest

# Stop and remove existing container if it exists
docker stop team7-app || true
docker rm team7-app || true

# Run the new container
docker run -d \
  --name team7-app \
  -p 80:3000 \
  --restart unless-stopped \
  ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}:latest

echo "App container started on port 80 (forwarded to 3000 internally)"