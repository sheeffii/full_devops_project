

locals {
 /* # Generate per-user key names when ssh_public_keys is provided. This will be a map of username => key_name.
  key_names = { for u, _ in var.ssh_public_keys : u => "${var.key_name_prefix}-${u}" }
  # Backwards-compatible single key name if current_user is set (not recommended for teams)
  key_name = var.current_user != "" ? "ssh-key-${var.current_user}" : null

  # Use var.current_user from tfvars (team-shared or per-user)
  key_name = "ssh-key-${var.current_user}"
*/
  # Try to read packer manifest (if present). Use try() so terraform validate won't fail when the file
  # doesn't exist locally. If the manifest exists, extract the AMI ID from it; otherwise leave ami_from_manifest empty.
  packer_manifest = try(jsondecode(file("../packer/packer-manifest.json")), null)
  ami_from_manifest = try(split(":", local.packer_manifest.builds[0].artifact_id)[1], "")
}


// If the packer manifest isn't available, fall back to a data source lookup for the most recent AMI
data "aws_ami" "packer_lookup" {
  most_recent = true

  filter {
    name   = "tag:BuiltBy"
    values = ["packer"]
  }

  filter {
    name   = "tag:Project"
    values = ["team7"]
  }

  # Look in the current account (packer produces AMIs in the same account by default)
  owners = ["self"]
}

locals {
  # Prefer AMI from packer manifest if present; otherwise use an AMI matched by tags.
  ami_id = local.ami_from_manifest != "" ? local.ami_from_manifest : data.aws_ami.packer_lookup.id
}


# dev/locals.tf
locals {
  sg_id = var.create_security_group ? aws_security_group.allow_access[0].id : data.aws_security_group.existing_sg[0].id
}