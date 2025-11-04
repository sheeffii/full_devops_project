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

# Install Prometheus Node Exporter
NODE_EXPORTER_VERSION="1.10.2"
cd /tmp
curl -LO "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"
tar xzf "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"
sudo mv "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter" /usr/local/bin/
sudo groupadd -r node_exporter || true
sudo useradd -r -s /bin/false -g node_exporter node_exporter || true
sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<EOF
[Unit]
Description=Prometheus Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter

# Cleanup temp files
rm -rf /tmp/node_exporter*

# Install cAdvisor for container metrics (pin version for prod stability)
sudo docker run -d \
  --name=cadvisor \
  --restart=always \
  --volume=/:/rootfs:ro \
  --volume=/var/run:/var/run:ro \
  --volume=/sys:/sys:ro \
  --volume=/var/lib/docker/:/var/lib/docker:ro \
  --volume=/dev/disk/:/dev/disk:ro \
  --publish=8080:8080 \
  --privileged \
  google/cadvisor:v0.53.0