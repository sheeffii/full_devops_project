variable "aws_region" {
  type        = string
  default     = "eu-central-1"
  description = "AWS region"

  validation {
    condition     = contains(["eu-central-1", "us-east-1"], var.aws_region)
    error_message = "Region must be eu-central-1 or us-east-1."
  }
}
/*
  validation {
    condition = contains([
      "eu-north-1", "us-east-1", "us-west-1", "us-west-2", "eu-west-1", "ap-southeast-1"
    ], var.aws_region)
    error_message = "Region must be one of the supported AWS regions."
  }
*/
/*
variable "ami_id" {
  type        = string
  description = "Packer-built Docker-ready AMI ID"
}


variable "current_user" {
  type        = string
  description = "(Optional) Current user running terraform. Kept for backwards compatibility."
  default     = ""
}
*/
variable "instance_type" {
  type        = string
  default     = "t2.micro"
  description = "EC2 instance type"

  validation {
    condition     = startswith(var.instance_type, "t2.") || startswith(var.instance_type, "t3.")
    error_message = "Instance type must be t2 or t3 family."
  }
/*
  validation {
  condition = can(regex("^(t2|t3|m5|c5)\\..+", var.instance_type))
  error_message = "Instance type must start with t2., t3., m5., or c5."
}
/*

 /* validation {
    condition     = contains(["t2.micro", "t2.small", "t2.medium"], var.instance_type)
    error_message = "The instance type must be one of: t2.micro, t2.small, t2.medium."
  } */
}
#IFRA-2
variable "ssh_public_keys" {
  type = map(string)
  description = "Mapping of username => path to SSH public key file on the machine running terraform. Example: { alice = \"C:/Users/Alice/.ssh/id_rsa.pub\" }"
  default = {}
}

variable "key_name_prefix" {
  type        = string
  description = "Prefix used when creating AWS key pair names. Final key name will be <prefix>-<username>"
  default     = "team7"
}
/*
variable "private_key_path" {
  type        = string
  description = "(Optional) Path to the private key file to use for remote-exec connection (only used by provisioners). Leave empty to skip."
  default     = ""
}

variable "provisioner_retries" {
  type        = number
  description = "Number of times to retry provisioner connection"
  default     = 3
}

variable "provisioner_retry_interval" {
  type        = string
  description = "Interval between provisioner retries (e.g., 10s, 30s)"
  default     = "10s"
}

variable "provisioner_timeout" {
  type        = string
  description = "Timeout for provisioner SSH connection (e.g., 4m)"
  default     = "4m"
}
*/
/*
variable "key_name" {
  type        = string
  default     = "my-ssh-key"
  description = "Name for the AWS key pair"
}


variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "subnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
}
*/

variable "private_key_path" {
  type        = string
  description = "Path to the private key file for remote-exec provisioner (e.g., '~/.ssh/id_rsa'). Leave empty to skip."
  default     = "~/.ssh/id_rsa"
}

# variables.tf
#variable "dynamodb_table_name" {
#  type    = string
#  default = "state_lock_table"
#}

variable "create_security_group" {
  description = "Create new SG (true) or use existing (false)"
  type        = bool
  default     = true
}

variable "tags" {
  type = map(string)
  default = {
    Name        = "dev-infra"
    Owner       = "dev7-team"
    Environment = "dev"
  }
  description = "Tags to apply to AWS resources"
}
