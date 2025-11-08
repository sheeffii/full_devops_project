# Alerting Setup Documentation

## Overview

This project includes a **complete alerting system** with Prometheus, Alertmanager, and Discord notifications. When alerts fire (high CPU, low disk, service down, etc.), you'll automatically receive notifications in your Discord channel with detailed information.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Prometheus                                │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  Evaluates alert.rules.yml every 15 seconds          │  │
│  │  • NodeExporterDown                                   │  │
│  │  • HighCPUUsage (>80%)                               │  │
│  │  • HighMemoryUsage (>85%)                            │  │
│  │  • LowDiskSpace (<15%)                               │  │
│  │  • CAdvisorDown                                      │  │
│  └───────────────────────────────────────────────────────┘  │
│                          ↓                                   │
│                 (Alerts Firing)                              │
│                          ↓                                   │
└──────────────────────────┼──────────────────────────────────┘
                           ↓
┌──────────────────────────┼──────────────────────────────────┐
│                   Alertmanager                               │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  Groups, deduplicates, and routes alerts             │  │
│  │  Configuration:                                       │  │
│  │  • Group by: alertname, severity, instance           │  │
│  │  • Repeat interval: 4 hours                          │  │
│  │  • Receiver: Discord webhook proxy                   │  │
│  └───────────────────────────────────────────────────────┘  │
└──────────────────────────┼──────────────────────────────────┘
                           ↓
┌──────────────────────────┼──────────────────────────────────┐
│            Discord Webhook Proxy (Python)                    │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  Converts Alertmanager JSON to Discord embeds        │  │
│  │  • Color-coded by severity                           │  │
│  │  • Shows status (firing/resolved)                    │  │
│  │  • Includes instance, severity, description          │  │
│  └───────────────────────────────────────────────────────┘  │
└──────────────────────────┼──────────────────────────────────┘
                           ↓
                    Discord Channel
                 (Your notifications!)
```

## Current Setup

### Alert Rules Location
```
full_devops_project/
└── infrastructure/monitoring/
    ├── configs/
    │   ├── alert.rules.yml          # Prometheus alert definitions
    │   └── alertmanager.yml         # Alertmanager routing config
    └── scripts/
        └── discord-webhook-proxy.py # Discord integration
```

### Integration
The complete alerting stack is deployed automatically via CI/CD:

1. **Alert rules** are loaded into Prometheus
2. **Alertmanager** receives firing alerts from Prometheus
3. **Discord Webhook Proxy** converts alerts to Discord embeds
4. **Notifications** sent to your Discord channel

All deployed via `infrastructure/scripts/deploy_monitoring.sh` which runs during infrastructure deployment.

---

## Alert Groups

### 1. Node Exporter Alerts

Monitors system-level metrics from the host machine.

#### **NodeExporterDown**
- **Expression**: `up{job="node-exporter"} == 0`
- **Duration**: 2 minutes
- **Severity**: Critical
- **Description**: Node Exporter service is unreachable
- **Impact**: System metrics unavailable; potential host issues
- **Response**: 
  1. SSH to EC2: `ssh ec2-user@<instance-ip>`
  2. Check service: `sudo systemctl status node_exporter`
  3. Check Docker: `sudo docker ps | grep node`
  4. Review logs: `sudo journalctl -u node_exporter -n 50`

#### **HighCPUUsage**
- **Expression**: `100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80`
- **Duration**: 5 minutes
- **Severity**: Warning
- **Description**: CPU usage exceeds 80%
- **Impact**: Performance degradation, potential service slowdown
- **Response**:
  1. Identify top processes: `top` or `htop`
  2. Check container resource usage: `sudo docker stats`
  3. Review application logs for errors
  4. Consider scaling horizontally (add instances)

#### **HighMemoryUsage**
- **Expression**: `(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85`
- **Duration**: 5 minutes
- **Severity**: Warning
- **Description**: Memory usage exceeds 85%
- **Impact**: Risk of OOM killer, application crashes
- **Response**:
  1. Check memory usage: `free -h`
  2. Identify memory hogs: `ps aux --sort=-%mem | head -20`
  3. Review container memory: `sudo docker stats --no-stream`
  4. Check for memory leaks in application
  5. Restart containers if needed: `sudo docker restart <container>`

#### **LowDiskSpace**
- **Expression**: `(node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100 < 15`
- **Duration**: 5 minutes
- **Severity**: Warning
- **Description**: Root disk space below 15%
- **Impact**: Cannot write logs, risk of disk full errors
- **Response**:
  1. Check disk usage: `df -h`
  2. Find large files: `sudo du -sh /* | sort -rh | head -10`
  3. Clean Docker resources:
     ```bash
     sudo docker system prune -a
     sudo docker volume prune
     ```
  4. Check logs: `sudo journalctl --disk-usage`
  5. Rotate logs: `sudo journalctl --vacuum-time=7d`

### 2. cAdvisor Alerts

Monitors container metrics collection.

#### **CAdvisorDown**
- **Expression**: `up{job="cadvisor"} == 0`
- **Duration**: 2 minutes
- **Severity**: Critical
- **Description**: cAdvisor container metrics collector is down
- **Impact**: Container metrics unavailable in Grafana
- **Response**:
  1. Check container: `sudo docker ps -a | grep cadvisor`
  2. Check logs: `sudo docker logs cadvisor`
  3. Restart: `sudo docker restart cadvisor`
  4. Verify access: `curl localhost:8080/healthz`

---

## Alert States

| State | Description |
|-------|-------------|
| **Inactive** | Alert condition not met; everything normal |
| **Pending** | Condition met but duration not reached yet |
| **Firing** | Condition met for specified duration; alert active |

---

## Viewing Alerts

### Prometheus UI
```
http://<ec2-ip>:9090/alerts
```
- View all configured alerts
- See current state (Inactive/Pending/Firing)
- Check alert duration and labels

### Alertmanager UI
```
http://<ec2-ip>:9093
```
- View active alerts
- See grouped alerts
- Silence alerts temporarily
- View notification history

### Discord Notifications

When an alert fires, you'll receive a Discord message like:

**🔥 CRITICAL: HighCPUUsage**
```
Summary: High CPU usage detected
Instance: ec2-node
Severity: WARNING
Status: FIRING
Description: CPU usage on ec2-node is above 80% (current value: 87.3%)
```

When resolved:
**✅ RESOLVED: HighCPUUsage**
```
Summary: High CPU usage detected
Instance: ec2-node
Status: RESOLVED
```

### API Queries

**Check all alert rules:**
```bash
curl http://<ec2-ip>:9090/api/v1/rules | jq '.data.groups[].rules[] | {alert: .name, state: .state, health: .health}'
```

**Check firing alerts:**
```bash
curl http://<ec2-ip>:9090/api/v1/alerts | jq '.data.alerts[] | {alert: .labels.alertname, instance: .labels.instance, state: .state, value: .value}'
```

**Test alert expression:**
```bash
# Example: Check current CPU usage
curl 'http://<ec2-ip>:9090/api/v1/query?query=100%20-%20(avg%20by(instance)%20(irate(node_cpu_seconds_total{mode=%22idle%22}[5m]))%20*%20100)'
```

---

## How It Works (Deployment)

### Automatic Deployment via CI/CD

When you push infrastructure changes or manually trigger deployment:

2. **GitHub Actions** runs the infrastructure workflow
3. **deploy_monitoring.sh** script executes:
   - Uploads `infrastructure/monitoring/configs/alert.rules.yml` to S3
   - Uploads `infrastructure/monitoring/configs/alertmanager.yml` to S3 (with Discord webhook URL injected)
   - Uploads `infrastructure/scripts/discord-webhook-proxy.py` to S3
   - Downloads configs to EC2 `/opt/monitoring/`
   
3. **Docker containers deployed** on EC2:
   - `prometheus`: Monitors metrics and evaluates alert rules
   - `alertmanager`: Manages alert routing and notification
   - `discord-proxy`: Converts alerts to Discord embeds
   - `node-exporter`, `cadvisor`: Collect metrics
   - `grafana`: Visualize metrics

4. **Discord webhook URL** passed via environment variable:
   ```yaml
   env:
     DISCORD_WEBHOOK_URL: ${{ secrets.DISCORD_WEBHOOK_URL }}
   ```

### Manual Deployment

```bash
cd infrastructure

# Set Discord webhook URL
export DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/YOUR/WEBHOOK"

# Deploy monitoring with alerting
bash scripts/deploy_monitoring.sh
```

---

## Alert Notification (ACTIVE!)

### Current State
- ✅ Alert rules defined and loaded
- ✅ Prometheus evaluates rules every 15 seconds
- ✅ Alertmanager configured and running
- ✅ Discord webhook proxy deployed
- ✅ Notifications sent to Discord automatically

### Configuration

**alertmanager.yml** (located in `infrastructure/monitoring/configs/`):
```yaml
route:
  receiver: 'discord'
  group_by: ['alertname', 'severity', 'instance']
  repeat_interval: 4h  # Don't spam - resend every 4 hours if still firing

receivers:
  - name: 'discord'
    webhook_configs:
      - url: 'http://discord-proxy:9094/webhook'
        send_resolved: true  # Send "resolved" notifications too
```

**Discord Webhook Proxy (discord-webhook-proxy.py):**
- Listens on port 9094
- Receives Alertmanager webhooks
- Converts to Discord embed format
- Sends to your Discord channel
- Color-coded by severity:
  - 🔥 Red: Critical
  - ⚠️ Orange: Warning
  - ℹ️ Blue: Info
  - ✅ Green: Resolved

---

## Testing Alerts

### Test Alert via Manual Trigger

```bash
# SSH to EC2
ssh ec2-user@<instance-ip>

# Simulate high CPU (will trigger after 5 minutes)
sudo apt install stress -y  # or yum install stress
stress --cpu 8 --timeout 600  # Run for 10 minutes

# Watch alerts in Prometheus
# Open: http://<ec2-ip>:9090/alerts
# You should see HighCPUUsage go from Inactive → Pending → Firing

# Check Discord - you should receive notification after 5 minutes
```

### Test Alertmanager Directly

```bash
# Send test alert to Alertmanager
curl -X POST http://<ec2-ip>:9093/api/v1/alerts \
  -H "Content-Type: application/json" \
  -d '[{
    "labels": {
      "alertname": "TestAlert",
      "severity": "warning",
      "instance": "test-instance"
    },
    "annotations": {
      "summary": "This is a test alert",
      "description": "Testing Discord notifications"
    }
  }]'

# Check Discord - should receive notification immediately
```

### Simulate Service Down

```bash
# Stop Node Exporter
sudo docker stop node-exporter

# Wait 2 minutes - NodeExporterDown alert will fire
# Check Discord for notification

# Restart
sudo docker start node-exporter

# Should receive "RESOLVED" notification
```

---

## Best Practices

1. **Alert Tuning**
   - Adjust thresholds based on baseline metrics
   - Set appropriate durations to avoid false positives
   - Use severity labels (critical, warning, info)

2. **Alert Fatigue Prevention**
   - Don't over-alert; focus on actionable items
   - Group related alerts
   - Use repeat_interval to avoid spam

3. **Documentation**
   - Document response procedures (runbooks)
   - Include escalation paths
   - Keep contact info updated

4. **Regular Testing**
   - Test alerts monthly
   - Verify notification channels
   - Update alert rules as infrastructure evolves

5. **Production Recommendations**
   - Enable Alertmanager for notifications
   - Configure multiple receivers (email + Slack/Discord)
   - Set up on-call rotations
   - Integrate with incident management (PagerDuty, Opsgenie)

---

## Troubleshooting

### Alerts Not Firing

**Check rule syntax:**
```bash
curl http://<ec2-ip>:9090/api/v1/status/config | jq '.data.yaml' | grep -A 20 'rule_files'
```

**Validate alert rules:**
```bash
# Reload Prometheus config
curl -X POST http://<ec2-ip>:9090/-/reload

# Check for errors
sudo docker logs prometheus | grep -i error
```

### False Positives

**Review metric history:**
```
http://<ec2-ip>:9090/graph
# Enter query, select "Graph" tab, adjust time range
```

**Adjust thresholds:**
Edit `infrastructure/monitoring/configs/alert.rules.yml` and redeploy monitoring stack.

### Missing Metrics

**Check scrape targets:**
```
http://<ec2-ip>:9090/targets
# All should show "UP"
```

**Verify exporters:**
```bash
curl http://<ec2-ip>:9100/metrics | grep node_cpu
curl http://<ec2-ip>:8080/metrics | grep container_cpu
```

---

## Alert Rule Reference

| Alert | Threshold | Duration | Severity | Job |
|-------|-----------|----------|----------|-----|
| NodeExporterDown | Up == 0 | 2m | Critical | node-exporter |
| HighCPUUsage | >80% | 5m | Warning | node-exporter |
| HighMemoryUsage | >85% | 5m | Warning | node-exporter |
| LowDiskSpace | <15% | 5m | Warning | node-exporter |
| CAdvisorDown | Up == 0 | 2m | Critical | cadvisor |

---

## Next Steps

- [ ] Deploy Alertmanager container
- [ ] Configure Discord webhook for alerts
- [ ] Add email notifications
- [ ] Create custom alerts for application metrics
- [ ] Integrate with PagerDuty for on-call
- [ ] Document runbooks for each alert
- [ ] Set up alert silencing during maintenance

---

**For more information:**
- [Prometheus Alerting](https://prometheus.io/docs/alerting/latest/overview/)
- [Alertmanager Configuration](https://prometheus.io/docs/alerting/latest/configuration/)
- [Alert Rule Best Practices](https://prometheus.io/docs/practices/alerting/)
