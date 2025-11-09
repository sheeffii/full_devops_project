# Infrastructure as Code (IaC) - Full DevOps Project

This infrastructure project implements a complete AWS deployment pipeline using Terraform, Packer, and Docker. The setup includes automated AMI building, state management, and EC2 deployment with team access management.

## Project Structure

```
infrastructure/
├── Makefile                 # Automation for all terraform operations
├── bootstrap/               # Backend infrastructure (S3 + DynamoDB)
│   ├── main.tf             # S3 bucket and DynamoDB table for remote state
│   └── outputs.tf          # Backend resource identifiers
├── dev/                    # Main infrastructure
│   ├── backend.tf         # Remote state configuration
│   ├── ec2.tf            # EC2 instance with Docker
│   ├── ecr.tf            # ECR repositories for Docker images
│   ├── iam.tf            # IAM roles and policies
│   ├── iam-ci.tf         # IAM policies for CI/CD (GitHub Actions)
│   ├── team-iam.tf       # Team member IAM users and policies
│   ├── keypair.tf        # SSH key management for team access
│   ├── locals.tf         # Local variables and data sources
│   ├── main.tf           # Provider configuration
│   ├── outputs.tf        # Public IP and connection info
│   ├── s3.tf            # S3 bucket for logs/backups
│   ├── security_group.tf # Firewall rules (22, 80, 3000, 8080, 9090, 9093, 9100)
│   ├── variables.tf      # Input variable definitions
│   ├── add_team_keys.sh  # User data script to add team SSH keys
│   └── example.tfvars    # Example variable values for team use
├── packer/               # AMI building
│   ├── packer-docker-ami.pkr.hcl  # Docker-ready AMI template
│   └── packer-manifest.json       # Build output (generated)
├── monitoring/           # Monitoring stack configuration
│   ├── docker-compose.yml         # Local monitoring stack (optional)
│   ├── README.md                  # Monitoring setup documentation
│   ├── configs/                   # Prometheus, Alertmanager, alert rules
│   │   ├── prometheus.yml
│   │   ├── alert.rules.yml
│   │   └── alertmanager.yml
│   ├── grafana-provisioning/      # Auto-provisioned datasources
│   │   ├── datasources/
│   │   │   └── prometheus.yml
│   │   └── dashboards/
│   │       └── dashboard.yml
│   └── grafana-dashboards/        # Pre-configured dashboards (JSON)
│       └── 1860_rev42.json        # Node Exporter Full dashboard
├── scripts/
│   ├── deploy_monitoring.sh       # Monitoring stack deployment via SSM
│   ├── discord-webhook-proxy.py   # Discord alert integration
│   ├── redeploy_on_boot.sh       # Auto-restart service script
│   └── install_redeploy_service.sh # Systemd service installer
└── systemd/
    └── redeploy-on-boot.service   # Systemd unit file for auto-redeploy

## Prerequisites

1. AWS CLI configured with appropriate credentials
2. Terraform (>= 1.0.0)
3. Packer (>= 1.8.0)
4. Make (for automation)

## Quick Start

1. **Initialize Backend Infrastructure**
   ```bash
   make bootstrap
   ```
   This creates:
   - S3 bucket for remote state storage
   - DynamoDB table for state locking

2. **Build Docker-ready AMI**
   ```bash
   cd packer
   packer init .
   packer build packer-docker-ami.pkr.hcl
   ```
   This creates an AMI with:
   - Amazon Linux 2023
   - Docker pre-installed and enabled
   - EC2 user added to docker group

3. **Deploy Main Infrastructure**
   ```bash
   # Copy and edit the example tfvars
   cp dev/example.tfvars dev/team.tfvars
   # Edit team.tfvars with your SSH keys and preferences
   
   # Deploy
   make deploy-testing TFVARS=team.tfvars
   ```

## Team SSH Access Management

The infrastructure supports multiple team members accessing the EC2 instance:

1. Edit `dev/team.tfvars` to add team members' SSH public keys (inline format):
   ```hcl
   ssh_public_keys = {
     shefqet = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQ... shefqet@TEAM"
     alice   = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQ... alice@TEAM"
     bob     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQ... bob@TEAM"
   }
   ```

2. The `add_team_keys.sh` user_data script automatically adds all team keys to EC2 on launch.
   Each team member can then SSH using their private key:
   ```bash
   ssh -i ~/.ssh/id_rsa ec2-user@<EC2_PUBLIC_IP>
   ```

## Infrastructure Components

### 1. Backend (bootstrap/)
- S3 bucket with versioning and encryption
- DynamoDB table for state locking
- No public access allowed

### 2. Docker AMI (packer/)
- Based on Amazon Linux 2023
- Docker pre-installed and configured
- Automatic versioning with timestamps
- Manifest file for Terraform integration

### 3. Main Infrastructure (dev/)
- EC2 instance using custom Docker AMI
- Elastic IP for stable access
- Security group with 7 ports: 22 (SSH), 80 (HTTP), 3000 (Grafana), 8080 (cAdvisor), 9090 (Prometheus), 9093 (Alertmanager), 9100 (Node Exporter)
- IAM roles with instance profile
- ECR repositories for Docker images
- S3 bucket for logs/backups and monitoring configs
- Team SSH key management
- Remote state configuration

### 4. Monitoring Stack (monitoring/)
- **Prometheus**: Metrics collection and alerting (port 9090)
- **Alertmanager**: Alert routing and notification (port 9093)
- **Grafana**: Visualization dashboards (port 3000)
- **Node Exporter**: System metrics (port 9100)
- **cAdvisor**: Container metrics (port 8080)
- **Discord Integration**: Custom webhook proxy for alert notifications
- Deployed via `deploy_monitoring.sh` script using AWS SSM
- Configs stored in S3 and pulled to EC2 at deployment time

### 5. Auto-Redeploy Service (Optional)
- Systemd service that auto-redeploys app on EC2 reboot
- Automatically installed via CI/CD pipeline after infrastructure deployment
- Files: `scripts/redeploy_on_boot.sh`, `systemd/redeploy-on-boot.service`
- Pulls latest image from ECR and restarts containers on every boot

## CI/CD Pipeline

The GitHub Actions workflow (`.github/workflows/infra-makefile.yml`) automatically:

1. **On Pull Request**: Quick validation (format, lint, validate)
2. **On Push to Main** or **Manual Deploy**:
   - Builds AMI with Packer
   - Deploys infrastructure with Terraform
   - Deploys monitoring stack (Prometheus, Grafana)
   - **Installs auto-redeploy service** on EC2

The auto-redeploy service ensures your app always runs the latest ECR image after any reboot.

## Security Features

1. **SSH Access**
   - Per-user SSH key pairs in AWS
   - No shared keys needed
   - Easy key rotation

2. **Network Security**
   - Limited open ports: 22 (SSH), 80 (HTTP), 3000 (Grafana), 8080 (cAdvisor), 9090 (Prometheus), 9093 (Alertmanager), 9100 (Node Exporter)
   - All other traffic blocked
   - EC2 in default VPC (customizable)

3. **State Management**
   - Encrypted S3 backend
   - State locking with DynamoDB
   - No public access to state

4. **IAM Security**
   - Minimal IAM roles
   - Instance profile for EC2
   - CI/CD user with minimal ECR permissions

## Remote State Backend

The project uses a two-step approach for state management:

1. Bootstrap phase uses local state
2. Main infrastructure uses remote state (S3 + DynamoDB)

This ensures clean separation and prevents chicken-egg problems with backend creation.

## Makefile Targets

- `make bootstrap` - Create backend infrastructure
- `make deploy-testing` - Deploy main infrastructure
- `make destroy` - Destroy all infrastructure
- `make clean` - Clean local Terraform files
- `make all` - Full pipeline (bootstrap → deploy)

## Best Practices Implemented

1. **Infrastructure**
   - Remote state with locking
   - Proper resource tagging
   - Security group rules
   - IAM least privilege

2. **Code Organization**
   - Modular structure
   - Clear separation of concerns
   - Documentation inline and in README
   - Example configurations

3. **Automation**
   - Makefile for common operations
   - Packer for image management
   - Docker for containerization
   - Clear deployment pipeline

## Error Handling

1. **AMI Creation**
   - Packer manifest tracks latest AMI
   - EC2 uses data source for AMI lookup
   - Fallback to latest if needed

2. **SSH Access**
   - Multiple key support
   - Graceful handling of missing keys
   - Clear error messages

3. **Deployment**
   - State locking prevents conflicts
   - Variable validation
   - Dependency management

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes following the patterns
4. Submit a pull request

## Troubleshooting

1. **AMI Not Found**
   - Check packer-manifest.json exists
   - Run packer build if needed
   - Verify region settings

2. **SSH Issues**
   - Verify key paths in tfvars
   - Check security group rules
   - Confirm private key permissions

3. **State Issues**
   - Run `make clean`
   - Re-initialize backend
   - Check AWS credentials

## Packer + Terraform workflow (recommended)

If you build AMIs locally with Packer and want Terraform to use the exact AMI produced:

1. Build the AMI with Packer (this produces `packer-manifest.json` in the `packer/` directory):

```powershell
cd infrastructure/packer
packer init .
packer build packer-docker-ami.pkr.hcl
```

2. Run Terraform in `infrastructure/dev`. Terraform will prefer the AMI from `packer/packer-manifest.json` if present; otherwise it will look up the most recent AMI tagged with `BuiltBy=packer` and `Project=full_devops_project` in the current account.

```powershell
cd infrastructure/dev
terraform init
terraform plan -var-file="example.tfvars"
terraform apply -var-file="example.tfvars"
```

3. Example `example.tfvars` for team SSH keys (place under `infrastructure/dev/example.tfvars`):

```hcl
aws_region     = "eu-central-1"
ssh_public_keys = {
   shefqet = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQ... shefqet@TEAM"
   alice   = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQ... alice@TEAM"
   bob     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQ... bob@TEAM"
}
instance_type    = "t3.micro"
private_key_path = "~/.ssh/id_rsa"  # optional, for provisioner
ci_user_name     = "github-deploy-bot"  # IAM user for CI/CD
tags = {
   Name        = "dev-infra"
   Owner       = "dev-team"
   Environment = "dev"
   Provisioner = "Terraform"
}
```

Notes:
- If you run Packer in CI and commit the manifest, Terraform will automatically use the manifest AMI.
- If you rely on AMIs produced elsewhere, ensure those AMIs are tagged with `BuiltBy=packer` and `Project=full_devops_project` so Terraform can find them.

### Using GitHub OIDC (recommended)

Instead of storing long-lived AWS credentials in GitHub secrets, prefer using GitHub OIDC to allow Actions to assume an IAM role in your AWS account.

1. Create an IAM role with a trust policy that allows GitHub Actions OIDC (example trust policy):

```json
{
   "Version": "2012-10-17",
   "Statement": [
      {
         "Effect": "Allow",
         "Principal": {
            "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
         },
         "Action": "sts:AssumeRoleWithWebIdentity",
         "Condition": {
            "StringLike": {
               "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
               "token.actions.githubusercontent.com:sub": "repo:YOUR_ORG/YOUR_REPO:*"
            }
         }
      }
   ]
}
```

2. Add the role ARN as a repository secret named `ROLE_TO_ASSUME`.

3. The CI workflow will automatically prefer OIDC (if `ROLE_TO_ASSUME` is set) and fall back to `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` if provided.

This avoids storing permanent keys in GitHub and is more secure.