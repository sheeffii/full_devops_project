output "ec2_public_ip" {
    value = aws_eip_association.eip_assoc.public_ip
}

output "ssh_connection" {
  value = "ssh -i ~/.ssh/id_rsa ec2-user@${aws_eip.elastic_ip.public_ip}"
}

output "created_key_pairs" {
  description = "Map of username => created AWS key pair name"
  value = length(keys(var.ssh_public_keys)) > 0 ? { for user, kp in aws_key_pair.user_keys : user => kp.key_name } : {}
}

output "ec2_instance_id" {
  value = aws_instance.ec2_instance.id
}