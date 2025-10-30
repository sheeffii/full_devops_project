resource "aws_security_group" "allow_access" {
    #vpc_id = aws_vpc.main.id 
    name        = "allow_access_sg"
    description = "Security group to allow SSH, HTTP, and monitoring access"
    #vpc_id = var.vpc_id
    count = var.create_security_group ? 1 : 0   # Create only if specified

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Restrict to your IP in production
  }

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow Node Exporter"
    from_port   = 9100 #
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # For Node Exporter/Monitoring
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"          # All protocols 
    cidr_blocks = ["0.0.0.0/0"] # Allow all outbound
  }

  tags = var.tags
}

# Data source for existing SG
data "aws_security_group" "existing_sg" {
  count = var.create_security_group ? 0 : 1
  filter {
    name   = "group-name"
    values = ["allow_access_sg"]
  }
}
