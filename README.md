# Full DevOps Project

Complete DevOps CI/CD pipeline with Infrastructure as Code and containerized application deployment.

## Status Badges

[![Infrastructure CI/CD Pipeline](https://github.com/sheeffii/full_devops_project/actions/workflows/infra-makefile.yml/badge.svg)](https://github.com/sheeffii/full_devops_project/actions/workflows/infra-makefile.yml)
[![Application CI/CD Pipeline](https://github.com/sheeffii/full_devops_project/actions/workflows/app-ci.yml/badge.svg)](https://github.com/sheeffii/full_devops_project/actions/workflows/app-ci.yml)

## Project Overview

This project demonstrates a complete DevOps workflow with separate CI/CD pipelines for:
- **Infrastructure**: Automated AWS infrastructure provisioning using Terraform and Packer
- **Application**: Node.js application with Docker containerization and automated deployment

## Quick Start

### Infrastructure
See [infrastructure/README.md](infrastructure/README.md) for details on deploying AWS infrastructure.

### Application
See [devop-2-main/README.md](devop-2-main/README.md) for running the application locally.

## CI/CD Documentation

See [docs/ci.md](docs/ci.md) for complete CI/CD pipeline documentation.

## Project Structure

```
full_devops_project/
├── infrastructure/          # Terraform, Packer, AWS infrastructure
│   ├── bootstrap/          # S3 + DynamoDB backend
│   ├── dev/                # EC2, ECR, security groups
│   ├── packer/             # Docker AMI builder
│   └── scripts/            # Deployment scripts
├── devop-2-main/           # Node.js application
│   ├── app/                # Express.js app with /health endpoint
│   └── Dockerfile          # Multi-stage Docker build
└── docs/                   # Documentation
    ├── ci.md              # CI/CD pipeline docs
    └── github-setup.md    # GitHub configuration guide
```

## Technologies

- **Cloud**: AWS (EC2, ECR, S3, DynamoDB, SSM)
- **IaC**: Terraform, Packer
- **CI/CD**: GitHub Actions
- **Containers**: Docker, Docker Compose
- **Monitoring**: Prometheus, Grafana, Node Exporter, cAdvisor
- **App**: Node.js, Express
- **Other**: Systemd, Bash scripting
- **Terraform**: Infrastructure as Code
- **Packer**: AMI building
- **Docker**: Containerization
- **GitHub Actions**: CI/CD automation
- **Node.js**: Application runtime
- **Express**: Web framework

