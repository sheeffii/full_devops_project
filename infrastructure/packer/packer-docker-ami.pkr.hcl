packer {
  required_plugins {
    amazon = {
      version = " >= 1.0.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

# Variables
variable "aws_region" {
  type        = string
  default     = "eu-central-1"
  description = "AWS region for building the AMI"
}

variable "ami_owner" {
  type        = string
  default     = "team7" 
  description = "Owner tag for the AMI"
}

# Source (Amazon Linux 2023 - recommended for longer support)

source "amazon-ebs" "docker_ami" {

  # Dev mode: Fixed name for fast overwrites (uncomment for prod versioning below)
  ami_name        = "team7-docker-ami-dev"  # Overwrites existing—quick rebuilds

  # Prod mode: Timestamped for versioning (comment out for dev)
  # ami_name        = "docker-ready-ami-{{timestamp}}"

  ami_description = "Amazon Linux 2023 with Docker pre-installed and SSM Agent pre-installed"
  instance_type   = "t3.micro"
  region          = var.aws_region

  source_ami_filter {
    filters = {
      name                = "al2023-ami-2023.*-x86_64"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners      = ["amazon"]
    most_recent = true
  }

  ssh_username = "ec2-user"

  tags = {
    Name    = "team7-docker-ami-dev"
    Owner   = var.ami_owner
    Project = "team7"
    BuiltBy = "packer"
    BuiltAt = "{{timestamp}}"
  }
}

# Build & Provisioning

build {
  name    = "docker-ami"
  sources = ["source.amazon-ebs.docker_ami"]

  provisioner "shell" {
    inline = [
      "set -e", // Exit immediately on any command failure
      "sudo dnf update -y",
      # Install SSM agent (Amazon Linux 2023) and ensure it's running
      "sudo dnf install -y amazon-ssm-agent || sudo yum install -y amazon-ssm-agent || true",
      "sudo systemctl enable --now amazon-ssm-agent || true",
      "sudo dnf install -y docker", 
      "sudo systemctl enable docker",
      "sudo systemctl start docker",
      "sudo usermod -aG docker ec2-user",
      "docker --version || echo 'Docker installation failed'"
    ]
  }

   post-processor "manifest" {
    output = "packer-manifest.json"
  }
}