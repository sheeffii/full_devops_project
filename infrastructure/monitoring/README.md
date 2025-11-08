# Monitoring Stack

This directory contains all monitoring and alerting configurations.

## Structure

```
infrastructure/monitoring/
├── configs/
│   ├── alert.rules.yml          # Prometheus alert definitions (deployed)
│   ├── alertmanager.yml         # Alertmanager routing configuration (deployed)
│   └── prometheus.yml           # Prometheus scrape/alert config (deployed)
├── grafana-dashboards/
│   └── 1860_rev42.json         # Node Exporter Full dashboard
├── grafana-provisioning/
│   ├── dashboards/
│   │   └── dashboard.yml       # Dashboard auto-provisioning config
│   └── datasources/
│       └── prometheus.yml      # Prometheus datasource config
```

## Components

### Alert Rules (`configs/alert.rules.yml`)
Prometheus alert definitions:
- **NodeExporterDown**: Metrics collection stopped
- **CAdvisorDown**: Container metrics stopped  
- **HighCPUUsage**: CPU >80% for 5 minutes
- **HighMemoryUsage**: Memory >85% for 5 minutes
- **LowDiskSpace**: Disk <15% free for 5 minutes

### Alertmanager (`configs/alertmanager.yml`)
Routes alerts to Discord via webhook proxy:
- Groups alerts by alertname, severity, instance
- Prevents spam (4-hour repeat interval)
- Sends resolved notifications

### Grafana Dashboards
Pre-configured dashboards:
- **Node Exporter Full** (1860): System metrics visualization

### Grafana Provisioning
Auto-provisions:
- Prometheus datasource connection
- Dashboard loading from `grafana-dashboards/`

## Deployment

Monitoring stack is deployed automatically via CI/CD:

```bash
# Triggered on infrastructure changes
git push origin main
```

Or manually:
```bash
cd infrastructure
bash scripts/deploy_monitoring.sh
```

## Access

After deployment:
- **Prometheus**: `http://<EC2_IP>:9090`
- **Alertmanager**: `http://<EC2_IP>:9093`
- **Grafana**: `http://<EC2_IP>:3000` (admin/admin)
- **Node Exporter**: `http://<EC2_IP>:9100/metrics`
- **cAdvisor**: `http://<EC2_IP>:8080`

## Notes

- All monitoring configuration files are static and stored in `infrastructure/monitoring/configs/`
- The deployment script uploads them to S3, then EC2 downloads and uses them
- The Discord webhook URL is passed to the proxy container via environment variable; never commit the real webhook
- All monitoring is provisioned automatically through CI/CD

## Documentation

Refer to central docs for details:
- **Setup Guide**: `docs/DISCORD_ALERTING_QUICKSTART.md`
- **Full Documentation**: `docs/ALERTING_SETUP.md`
- **Quick Reference**: `docs/MONITORING_QUICK_REF.md`

All monitoring assets above are the canonical source for the automated deployment.
