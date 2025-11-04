/*
resource "aws_instance" "ec2_instance" {
  ami           = local.ami_id           # Use the ami_id defined in terraform.tfvars
  instance_type = var.instance_type
  #subnet_id     = aws_subnet.public_subnet.id  
  #vpc_security_group_ids = [aws_security_group.allow_access.id]
  vpc_security_group_ids = [local.sg_id]  # ← CORRECTED LINE
  key_name = try(
    aws_key_pair.user_keys[var.current_user].key_name,
    length(keys(aws_key_pair.user_keys)) == 1 ? values(aws_key_pair.user_keys)[0].key_name : null
  )
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name # Use the instance profile defined in iam.tf


  # Use 'user_data' to ensure Docker starts automatically on EC2 boot
  user_data = <<-EOF
    #!/bin/bash
    # Start Docker service on boot
    sudo systemctl enable docker
    sudo systemctl start docker

    # Run a Docker container (Nginx in this case)
    sudo docker run -d -p 80:80 --name webserver nginx
  EOF
  #OR
  # user_data = file("../scripts/install_docker.sh")  # Path to your bash script

  tags = var.tags
}
*/
# dev/ec2.tf
resource "aws_instance" "ec2_instance" {
  ami           = local.ami_id
  instance_type = var.instance_type

  # Use the smart SG (create or reuse)
  vpc_security_group_ids = [local.sg_id]

  # Pick ONE key for AWS console (any team member)
  key_name = values(aws_key_pair.user_keys)[0].key_name
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  # ADD ALL TEAM SSH KEYS + START DOCKER
  # Pass only the public key values as a list to the template
  user_data = templatefile("${path.module}/add_team_keys.sh", {
    team_keys = values(var.ssh_public_keys)
  })

  tags = var.tags
}

# Allocate an Elastic IP
resource "aws_eip" "elastic_ip" { 
  domain = "vpc"
  tags   = var.tags
}

# Associate the Elastic IP with the EC2 instance
resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.ec2_instance.id 
  allocation_id = aws_eip.elastic_ip.id
}


# Simple remote-exec (like your older code)
resource "null_resource" "after_eip_setup" {
  # Only enable this provisioner when explicitly requested (avoid failures in CI runners)
  count = var.enable_provisioner ? 1 : 0

  depends_on = [aws_eip_association.eip_assoc]

  triggers = {
    instance_id = aws_instance.ec2_instance.id
    eip         = aws_eip.elastic_ip.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "echo '--- Provisioner started ---'",
      "sudo systemctl is-active docker || sudo systemctl start docker",
      "echo 'Docker status: $$(sudo systemctl is-active docker)'",
      "sudo docker ps -a || true",
      "echo '--- Provisioner finished ---'"
    ]

    connection {
      type = "ssh"
      user = "ec2-user"

      # Use provided key content when available, otherwise read from a file path.
      # The file() call is only used when `private_key_path` is non-empty and the file exists
      private_key = var.private_key_content != "" ? var.private_key_content : (
        var.private_key_path != "" && fileexists(var.private_key_path) ? file(var.private_key_path) : ""
      )

      host    = aws_eip.elastic_ip.public_ip
      timeout = "4m"
    }
  }
}