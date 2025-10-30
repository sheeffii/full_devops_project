#!/bin/bash

# Update system
sudo yum update -y

# Install Docker if not installed
if ! command -v docker &> /dev/null
then
    echo "Docker not found, installing..."
    sudo yum install -y docker
fi

# Enable Docker to start on boot
sudo systemctl enable docker

# Start Docker service
sudo systemctl start docker

# Run Nginx container (for example)
sudo docker run -d -p 80:80 --name webserver nginx
