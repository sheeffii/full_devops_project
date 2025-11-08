# 🚀 Quick Reference - Monitoring Stack

## One-Command Deploy
```bash
cd infrastructure && make all
```

## Access URLs (after deploy)
```bash
# Get EC2 IP
cd infrastructure/dev && terraform output instance_public_ip

# Then access:
http://<ec2-ip>:3000   # Grafana (admin/admin)
http://<ec2-ip>:9090   # Prometheus
http://<ec2-ip>:9100   # Node Exporter
http://<ec2-ip>:8080   # cAdvisor
```

## Common Commands

### Deploy/Update Monitoring
```bash
cd infrastructure
make deploy-monitoring
```

### Check Status
```bash
# SSH to EC2
ssh ec2-user@<ec2-ip>

# Check all containers
sudo docker ps

# Check Node Exporter
sudo systemctl status node_exporter

# View Prometheus targets
curl localhost:9090/api/v1/targets | jq '.data.activeTargets[].health'
```

### View Logs
```bash
sudo docker logs prometheus
sudo docker logs grafana
sudo journalctl -u node_exporter -f
```

### Restart Services
```bash
sudo docker restart prometheus
sudo docker restart grafana
sudo systemctl restart node_exporter
sudo docker restart cadvisor
```

## GitHub Actions

### Auto Deploy (on push to main)
- Infrastructure + Monitoring deploys automatically (single pipeline)

### Manual Deploy
- Actions → "Infrastructure CI/CD" → Run workflow → choose action "deploy"

## Grafana Dashboards

1. Login: http://<ec2-ip>:3000 (admin/admin)
2. Dashboards → Browse
3. Select "Node Exporter Full"
4. Use dropdowns to filter by Job/Node

## Alert Status

Check: http://<ec2-ip>:9090/alerts

### Configured Alerts (infrastructure/monitoring/configs/alert.rules.yml)

**Node Exporter Alerts:**
- **NodeExporterDown**: Triggers when Node Exporter is unreachable for >2 minutes (CRITICAL)
- **HighCPUUsage**: CPU usage >80% for 5 minutes (WARNING)
- **HighMemoryUsage**: Memory usage >85% for 5 minutes (WARNING)
- **LowDiskSpace**: Root disk space <15% for 5 minutes (WARNING)

**cAdvisor Alerts:**
- **CAdvisorDown**: Triggers when cAdvisor is unreachable for >2 minutes (CRITICAL)

### Alert Rule Details

```yaml
# View current alert rules
curl http://<ec2-ip>:9090/api/v1/rules | jq '.data.groups[].rules[] | {alert: .name, state: .state}'

# Check firing alerts
curl http://<ec2-ip>:9090/api/v1/alerts | jq '.data.alerts[] | {alert: .labels.alertname, state: .state}'
```

### Alert Configuration

Alert rules are loaded from `infrastructure/monitoring/configs/alert.rules.yml` into Prometheus during deployment via S3:
```bash
# Deployed to EC2 at:
/opt/monitoring/prometheus/alert.rules.yml
```

**Note**: Alerts are defined but no Alertmanager is configured. To receive notifications:
1. Deploy Alertmanager container
2. Configure receivers (email, Slack, Discord, PagerDuty)
3. Update prometheus.yml with alertmanager targets

## Ports Reference

| Service        | Port | Purpose               |
|----------------|------|-----------------------|
| App            | 80   | Node.js application   |
| SSH            | 22   | Remote access         |
| Grafana        | 3000 | Dashboards/UI         |
| cAdvisor       | 8080 | Container metrics     |
| Prometheus     | 9090 | Metrics & alerts      |
| Node Exporter  | 9100 | System metrics        |

## File Locations on EC2

```
/opt/monitoring/
├── prometheus/
│   ├── prometheus.yml
│   └── alert.rules.yml
├── alertmanager/
│   └── alertmanager.yml
├── grafana-provisioning/
│   ├── datasources/
│   │   └── prometheus.yml
│   └── dashboards/
│       └── dashboard.yml
├── grafana-dashboards/
│   └── 1860_rev42.json
└── discord-webhook-proxy.py
```

## Quick Tests

```bash
# Test Node Exporter
curl http://<ec2-ip>:9100/metrics | head -20

# Test Prometheus targets
curl http://<ec2-ip>:9090/api/v1/targets

# Test Grafana health
curl http://<ec2-ip>:3000/api/health

# Test cAdvisor
curl http://<ec2-ip>:8080/healthz
```

## Troubleshooting

**Services not running?**
```bash
sudo docker ps -a  # Check container status
sudo systemctl status node_exporter
```

**Prometheus not scraping?**
```bash
# Check if targets are accessible
curl localhost:9100/metrics
curl localhost:8080/metrics
```

**Grafana dashboard empty?**
```bash
# Test datasource connection
curl http://localhost:9090/-/healthy
```

**Config changes not applied?**
```bash
# Redeploy monitoring
cd infrastructure && make deploy-monitoring
```

## Production Tips

1. **Change Grafana password** immediately after first login
2. **Restrict security group** IPs for ports 3000, 9090, 9100, 8080 via tfvars:
    - `allowed_ssh_cidrs`, `allowed_app_cidrs`, `allowed_monitoring_cidrs`
3. **Set up Alertmanager** for notifications (Slack, email)
4. **Enable HTTPS** with reverse proxy (nginx + Let's Encrypt)
5. **Backup Grafana dashboards** regularly

## Useful Links

- [Complete Guide](MONITORING_SETUP.md)
- [Monitoring Docs](monitoring.md)
- [Infrastructure README](../infrastructure/README.md)
- [CI/CD Docs](ci.md)
