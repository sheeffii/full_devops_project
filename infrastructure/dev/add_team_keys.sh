#!/bin/bash
set -e

# Create .ssh
mkdir -p /home/ec2-user/.ssh
chmod 700 /home/ec2-user/.ssh

# Clear file
> /home/ec2-user/.ssh/authorized_keys

# Add each key
%{ for key in team_keys ~}
echo "${key}" >> /home/ec2-user/.ssh/authorized_keys
%{ endfor ~}

chmod 600 /home/ec2-user/.ssh/authorized_keys
chown -R ec2-user:ec2-user /home/ec2-user/.ssh

# Start Docker
sudo systemctl enable docker
sudo systemctl start docker
sudo docker run -d -p 80:80 --name webserver nginx