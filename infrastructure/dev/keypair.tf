// Create one aws_key_pair per entry in var.ssh_public_keys (username => path)
// This allows the team to supply multiple public keys and create named keypairs in AWS.

locals {
  valid_ssh_keys = {
    for user, key in var.ssh_public_keys : user => key
    if length(key) > 50 && startswith(key, "ssh-")
  }
}

resource "aws_key_pair" "user_keys" {
  for_each = local.valid_ssh_keys  # Only valid ones

  key_name = "${var.key_name_prefix}-${each.key}"

  # Support passing either the public key content directly (starts with "ssh-")
  # or a local path to a public key file. If the value starts with "ssh-",
  # treat it as the public key content; otherwise read the file from disk.
  public_key = startswith(each.value, "ssh-") ? each.value : file(each.value)

  tags = merge(var.tags, { CreatedBy = "terraform" })
}

// Note: Provide ssh public key content via tfvars (inline preferred for teams)