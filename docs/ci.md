# CI/CD Pipeline Documentation

## Status Badges
[![Infrastructure CI/CD Pipeline](https://github.com/sheeffii/full_devops_project/actions/workflows/infra-workflow.yml/badge.svg)](https://github.com/sheeffii/full_devops_project/actions/workflows/infra-workflow.yml)
[![Application CI/CD Pipeline](https://github.com/sheeffii/full_devops_project/actions/workflows/app-workflow.yml/badge.svg)](https://github.com/sheeffii/full_devops_project/actions/workflows/app-workflow.yml)

## Pipeline Overview

Our CI/CD implementation consists of two separate workflows:

### Infrastructure Pipeline (infra-workflow.yml)
- Validates AWS credentials
- Runs Terraform linting
- Builds AMI with Packer
- Plans and applies Terraform changes
- Requires approval for production deployment

### Application Pipeline (app-workflow.yml)
- Runs Dockerfile linting
- Executes application tests
- Builds and pushes Docker image
- Deploys to EC2 instances
- Requires approval for production deployment

## Implementation Details

CI-1: Created `.github/workflows/` with separate workflow files
CI-2: AWS credentials configured using aws-actions/configure-aws-credentials
CI-3: AWS credential verification with sts get-caller-identity
CI-4: Packer AMI build workflow in infrastructure pipeline
CI-5: Workflows trigger on PR and push to main branch
CI-6: Status badges added for both pipelines
CI-7: Split into separate infrastructure and application workflows
CI-8: Added linting and testing for both infrastructure and application
CI-9: Required checks and approvals for production deployments
CI-10: This documentation provides complete pipeline overview

## Required Secrets

The following secrets must be configured in GitHub:
- AWS_ACCESS_KEY_ID
- AWS_SECRET_ACCESS_KEY

## Protection Rules

- Production deployments require approval
- All tests must pass before merge
- Branch protection enforced on main