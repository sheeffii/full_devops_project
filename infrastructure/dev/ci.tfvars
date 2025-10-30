aws_region     = "eu-north-1"
# For CI we don't provide SSH public key files (runners don't have team member keys).
ssh_public_keys = {}
instance_type  = "t3.micro"
current_user = ""
private_key_path = ""

tags = {
  Name        = "dev-infra-ci"
  Owner       = "ci"
  Environment = "ci"
}
