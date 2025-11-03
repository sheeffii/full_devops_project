aws_region     = "eu-central-1"
# Example of providing multiple SSH public keys for the team. Keys should point to the public key files on the machine running Terraform.
ssh_public_keys = {
  # Option A: provide paths to local public key files (for local development)
  shefqet = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDkilGs+ZszEnFLQFPEIVxSTTQwR/B31XKZ2EDGsATcCIJUZjn9yvf+1sQ7OsoZFgDcNJAeTJjTNAag2EewKH8PB4dzC4VUt4T4gsCrqjbtXdeP3ISBC91aL9zrftLt1gx9r1O4Z4sp+nk4L8810RLK8nNeymFiaI/l0RFr8YVYZqlvvpPZ9WsperCwAOovCWkDh8XpbY9qK60RF3X12ITqOnYzaJll5ToHn5XILryurLaSh9zMGDJf8hEC/KY5P8xtf15akFoq7A4bNtd1eAe34YMM8hMDDWlaB+KtWiBmyRfyUYJv47Xpy3di8J0hP6sPYn/feh79MK7kfUal8ptP sheeffii@SHS"
  test_user = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDkilGs+ZszEnFLQFPEIVxSTTQwR/B31XKZ2EDGsATcCIJUZjn9yvf+1sQ7OsoZFgDcNJAeTJjTNAag2EewKH8PB4dzC4VUt4T4gsCrqjbtXdeP3ISBC91aL9zrftLt1gx9r1O4Z4sp+nk4L8810RLK8nNeymFiaI/l0RFr8YVYZqlvvpPZ9WsperCwAOovCWkDh8XpbY9qK60RF3X12ITqOnYzaJll5ToHn5XILryurLaSh9zMGDJf8hEC/KY5P8xtf15akFoq7A4bNtd1eAe34YMM8hMDDWlaB+KtWiBmyRfyUYJv47Xpy3di8J0hP6sPYn/feh79MK7kfUal8ptP test@LOCAL"

  # Qendresa (placeholder—uncomment and paste full key when ready)
  # qendresa = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC3... [full Qendresa key here] alice@EXAMPLE"

  # Drilon (placeholder—add when ready)
  # drilon = "ssh-rsa AAAAB3NzaC1yc2E... [full drilon key] drilon@TEAM"

  # Beqir (placeholder—add when ready)
  # beqir = "ssh-rsa AAAAB3NzaC1yc2E... [full drilon key] beqir@TEAM"
}

instance_type  = "t3.micro"
#current_user = "shefqet"
private_key_path = "~/.ssh/id_rsa"

# Optional: set the IAM user that GitHub Actions uses (access keys in repo secrets)
# When set, Terraform will attach the minimal ECR push policy to this user.
ci_user_name = "github-deploy-bot"

# Override default tags if needed
tags = {
  Name        = "dev-infra"
  Owner       = "team7"
  Environment = "dev"
  Provisioner = "Terraform"
}