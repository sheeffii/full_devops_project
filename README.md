# Full DevOps Project

Complete DevOps CI/CD pipeline with Infrastructure as Code, automated monitoring, alerting, and containerized application deployment on AWS.

## Status Badges

[![Infrastructure CI/CD Pipeline](https://github.com/sheeffii/full_devops_project/actions/workflows/infra-makefile.yml/badge.svg)](https://github.com/sheeffii/full_devops_project/actions/workflows/infra-makefile.yml)
[![Application CI/CD Pipeline](https://github.com/sheeffii/full_devops_project/actions/workflows/app-ci.yml/badge.svg)](https://github.com/sheeffii/full_devops_project/actions/workflows/app-ci.yml)
[![Discord Bot CI/CD](https://github.com/sheeffii/full_devops_project/actions/workflows/bot-ci.yml/badge.svg)](https://github.com/sheeffii/full_devops_project/actions/workflows/bot-ci.yml)
[![Docker](https://img.shields.io/badge/Docker-Enabled-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
[![Terraform](https://img.shields.io/badge/IaC-Terraform-7B42BC?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Prometheus](https://img.shields.io/badge/Monitoring-Prometheus-E6522C?logo=prometheus&logoColor=white)](https://prometheus.io/)
[![Grafana](https://img.shields.io/badge/Dashboards-Grafana-F46800?logo=grafana&logoColor=white)](https://grafana.com/)

## ✨ Features

- 🚀 **Fully Automated CI/CD**: GitHub Actions workflows for infrastructure, application, and Discord bot
- 🏗️ **Infrastructure as Code**: Terraform for AWS resource management, Packer for custom AMI building
- 📊 **Complete Monitoring Stack**: Prometheus, Grafana, Alertmanager with Discord notifications
- 🐳 **Containerized Deployment**: Docker containers for all services, automated image building and deployment
- 🔐 **Security Best Practices**: IAM roles, encrypted state storage, SSH key management, private S3 buckets
- 🔄 **Auto-Restart on Boot**: Systemd service ensures applications restart after EC2 reboots
- 📈 **Real-time Alerts**: Discord webhook integration for infrastructure and application alerts

## Project Overview

This project demonstrates a complete DevOps workflow with separate CI/CD pipelines for:
- **Infrastructure**: Automated AWS infrastructure provisioning using Terraform and Packer
- **Application**: Node.js application with Docker containerization and automated deployment
- **Discord Bot**: Python-based Discord bot with CI/CD pipeline
- **Monitoring**: Automated deployment of Prometheus, Grafana, and Alertmanager with Discord alerting

## Quick Start

### Prerequisites
- AWS account with appropriate credentials
- GitHub account with repository access
- Docker installed locally (for local development)

### 1. Set Up GitHub Secrets
Configure the following secrets in your GitHub repository (`Settings` → `Secrets and variables` → `Actions`):

**Required:**
- `AWS_ACCESS_KEY_ID` - AWS access key
- `AWS_SECRET_ACCESS_KEY` - AWS secret key
- `DISCORD_WEBHOOK_URL` - Discord webhook for alerts (optional but recommended)

**Optional (for OIDC):**
- `ROLE_TO_ASSUME` - AWS IAM role ARN for GitHub OIDC authentication

### 2. Deploy Infrastructure
```bash
# Infrastructure is automatically deployed on push to main
git push origin main

# Or manually trigger via GitHub Actions UI
# Navigate to Actions → Infrastructure CI/CD → Run workflow
```

### 3. Access Services
After deployment completes (check GitHub Actions logs for URLs):
- **Application**: `http://<EC2_IP>:80`
- **Prometheus**: `http://<EC2_IP>:9090`
- **Alertmanager**: `http://<EC2_IP>:9093`
- **Grafana**: `http://<EC2_IP>:3000` (admin/admin)

### Detailed Guides
- **Infrastructure Setup**: See [infrastructure/README.md](infrastructure/README.md)
- **Application Development**: See [devop-2-main/README.md](devop-2-main/README.md)
- **Monitoring & Alerting**: See [docs/DISCORD_ALERTING_QUICKSTART.md](docs/DISCORD_ALERTING_QUICKSTART.md)
- **CI/CD Pipeline**: See [docs/ci.md](docs/ci.md)

## Project Structure

```
full_devops_project/
├── .github/workflows/          # CI/CD pipelines
│   ├── infra-makefile.yml     # Infrastructure deployment
│   ├── app-ci.yml             # Application deployment
│   └── bot-ci.yml             # Discord bot deployment
├── infrastructure/             # Terraform, Packer, AWS infrastructure
│   ├── bootstrap/             # S3 + DynamoDB backend
│   ├── dev/                   # EC2, ECR, security groups, IAM
│   ├── monitoring/            # Monitoring configs and dashboards
│   │   ├── configs/           # Prometheus, Alertmanager, alert rules
│   │   ├── grafana-dashboards/    # Pre-built Grafana dashboards
│   │   └── grafana-provisioning/  # Auto-provisioning configs
│   ├── packer/                # Docker AMI builder
│   └── scripts/               # Deployment and automation scripts
│       ├── deploy_monitoring.sh   # Monitoring stack deployment
│       ├── discord-webhook-proxy.py  # Alert notification service
│       └── redeploy_on_boot.sh    # Auto-restart service
├── devop-2-main/              # Node.js application
│   ├── app/                   # Express.js app with /health endpoint
│   └── Dockerfile             # Multi-stage Docker build
├── discord-bot/               # Discord bot application
│   ├── bot.py                 # Bot logic and commands
│   └── Dockerfile             # Python container
└── docs/                      # Documentation
    ├── ARCHITECTURE.md                # Complete architecture guide
    ├── ALERTING_SETUP.md              # Alerting documentation
    ├── DISCORD_ALERTING_QUICKSTART.md # Quick setup guide
    ├── MONITORING_QUICK_REF.md        # Monitoring reference
    ├── ci.md                          # CI/CD pipeline docs
    └── github-setup.md                # GitHub configuration guide
```

## Key Features

### 🔄 Automated CI/CD Workflows
- **Sequential Pipeline**: Infrastructure → Application → Bot deployment
- **Change Detection**: Only rebuilds/redeploys when relevant files change
- **Workflow Dispatch**: Manual trigger support for all pipelines
- **Discord Notifications**: Real-time deployment status updates

### 📊 Complete Monitoring Solution
- **Metrics Collection**: System, container, and application metrics
- **Pre-built Dashboards**: Node Exporter Full dashboard included
- **Alerting Rules**: CPU, memory, disk, and service availability alerts
- **Discord Integration**: Automatic alert notifications with color-coded severity

### 🔐 Security & Best Practices
- **IAM Roles**: Instance profiles with least-privilege permissions
- **Encrypted Storage**: S3 state backend with encryption at rest
- **State Locking**: DynamoDB prevents concurrent modification
- **SSH Key Management**: Per-user key pairs, no shared credentials
- **Private Registry**: ECR for secure Docker image storage
- **Secret Management**: GitHub Secrets for sensitive values

### 🚀 Deployment Features
- **Zero-Downtime Deploys**: Rolling container updates
- **Auto-Restart**: Systemd service restarts containers on boot
- **Health Checks**: Automated health endpoint monitoring
- **S3 Asset Distribution**: Secure config distribution via S3 + SSM

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is for educational and demonstration purposes.

## Support

For issues, questions, or contributions:
- 📝 Open an issue in the GitHub repository
- 📖 Check the [documentation](docs/)
- 🔍 Review [CI/CD workflows](.github/workflows/)

---

**Built with ❤️ using modern DevOps practices**

## Technologies

### Cloud & Infrastructure
- **AWS Services**: EC2, ECR, S3, DynamoDB, Systems Manager (SSM)
- **IaC**: Terraform (infrastructure provisioning), Packer (AMI building)
- **Automation**: Makefile, Bash scripting

### CI/CD & Containers
- **CI/CD**: GitHub Actions with workflow orchestration
- **Containers**: Docker for all services and applications
- **Registry**: AWS ECR for private Docker image storage

### Monitoring & Alerting
- **Metrics**: Prometheus (collection & alerting), Node Exporter, cAdvisor
- **Visualization**: Grafana with pre-configured dashboards
- **Alerting**: Alertmanager with Discord webhook integration
- **Custom Proxy**: Python-based Discord notification service

### Applications
- **Node.js App**: Express.js with health check endpoints
- **Discord Bot**: Python with discord.py library
- **Auto-Restart**: Systemd service for container management

## Architecture

### Infrastructure Flow
```
GitHub Actions (CI/CD)
        ↓
    Push to ECR
        ↓
    Deploy to EC2 (via SSM)
        ↓
    Docker Containers
    ├── Application (Node.js)
    ├── Prometheus (monitoring)
    ├── Alertmanager (alerts)
    ├── Discord Proxy (notifications)
    ├── Grafana (dashboards)
    ├── Node Exporter (metrics)
    └── cAdvisor (container metrics)
```

### Monitoring & Alerting Flow
```
Prometheus → Alertmanager → Discord Proxy → Discord Channel
     ↓
  Grafana (visualization)
```

For detailed architecture, see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Documentation

### Core Guides
- 📖 [Architecture Overview](docs/ARCHITECTURE.md) - Complete system architecture
- 🚀 [CI/CD Pipeline](docs/ci.md) - GitHub Actions workflow details
- 🔧 [Infrastructure Setup](infrastructure/README.md) - Terraform & Packer guide

### Monitoring & Alerting
- 🔔 [Discord Alerting Quickstart](docs/DISCORD_ALERTING_QUICKSTART.md) - Fast setup guide
- 📊 [Alerting Setup](docs/ALERTING_SETUP.md) - Detailed alerting configuration
- 📈 [Monitoring Quick Reference](docs/MONITORING_QUICK_REF.md) - Metrics and alerts reference

### Additional Resources
- ⚙️ [GitHub Setup Guide](docs/github-setup.md) - Repository configuration
- 🔄 [Monitoring Reorganization](docs/MONITORING_REORGANIZATION.md) - File structure changes
- ✅ [Alerting Implementation](docs/ALERTING_IMPLEMENTATION.md) - Alert system summary

