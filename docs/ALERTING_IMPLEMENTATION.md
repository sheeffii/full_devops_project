# ✅ Discord Alerting Implementation Complete!

## What Was Added

### 1. **Alertmanager Configuration** (`infrastructure/monitoring/configs/alertmanager.yml`)
- Routes alerts from Prometheus to Discord
- Groups alerts by alertname, severity, instance
- Prevents alert spam (repeat every 4 hours)
- Sends "resolved" notifications

### 2. **Discord Webhook Proxy** (`infrastructure/scripts/discord-webhook-proxy.py`)
- Python service that converts Alertmanager JSON to Discord embeds
- Color-coded alerts:
  - 🔥 Red (Critical)
  - ⚠️ Orange (Warning)
  - ℹ️ Blue (Info)
  - ✅ Green (Resolved)
- Shows instance, severity, status, description
- Runs as Docker container on EC2

### 3. **Updated Deployment Script** (`infrastructure/scripts/deploy_monitoring.sh`)
- Downloads and deploys Alertmanager
- Deploys Discord webhook proxy
- Injects Discord webhook URL from environment
- Connects all services via Docker network

### 4. **Updated CI/CD Workflow** (`.github/workflows/infra-makefile.yml`)
- Passes `DISCORD_WEBHOOK_URL` from GitHub Secrets to deployment
- Automatically deploys alerting stack with monitoring

### 5. **Updated Security Group** (`infrastructure/dev/security_group.tf`)
- Added port 9093 for Alertmanager UI access

### 6. **Updated Boot Script** (`infrastructure/scripts/redeploy_on_boot.sh`)
- Auto-restarts Alertmanager and Discord proxy on instance reboot

### 7. **Documentation**
- **ALERTING_SETUP.md**: Complete technical documentation
- **DISCORD_ALERTING_QUICKSTART.md**: Quick setup guide
- **MONITORING_QUICK_REF.md**: Updated with alert details

---

## How It Works

```
Alert Condition Met (e.g., CPU >80%)
         ↓
Prometheus evaluates alert.rules.yml
         ↓
Alert FIRING after duration (5 min)
         ↓
Prometheus sends to Alertmanager (port 9093)
         ↓
Alertmanager groups/routes alert
         ↓
Sends webhook to discord-proxy (port 9094)
         ↓
discord-proxy converts to Discord embed
         ↓
Posts to Discord channel
         ↓
You receive notification! 🎉
```

---

## Deployment Flow

When you deploy infrastructure (push or manual):

1. **GitHub Actions** triggers infrastructure workflow
2. **deploy_monitoring.sh** runs with `DISCORD_WEBHOOK_URL` env var
3. Uploads configs to S3:
   - `infrastructure/monitoring/configs/alert.rules.yml` (alert definitions)
   - `infrastructure/monitoring/configs/alertmanager.yml` (with webhook URL injected)
   - `infrastructure/scripts/discord-webhook-proxy.py` (Python proxy script)
4. EC2 downloads configs from S3
5. Deploys Docker containers:
   - `prometheus` (monitors + evaluates alerts)
   - `alertmanager` (routes alerts)
   - `discord-proxy` (sends to Discord)
   - `node-exporter`, `cadvisor` (collect metrics)
   - `grafana` (visualize)

All services connected via Docker network `monitoring`

---

## Files Modified/Created

### Created:
- ✅ `infrastructure/monitoring/configs/alertmanager.yml`
- ✅ `infrastructure/monitoring/configs/alert.rules.yml` (moved from root)
- ✅ `infrastructure/monitoring/README.md`
- ✅ `infrastructure/scripts/discord-webhook-proxy.py`
- ✅ `docs/DISCORD_ALERTING_QUICKSTART.md`
- ✅ `docs/ALERTING_SETUP.md` (updated with full details)

### Modified:
- ✅ `infrastructure/scripts/deploy_monitoring.sh`
- ✅ `infrastructure/scripts/redeploy_on_boot.sh`
- ✅ `.github/workflows/infra-makefile.yml`
- ✅ `infrastructure/dev/security_group.tf`
- ✅ `docs/MONITORING_QUICK_REF.md`

---

## Next Steps

### 1. Verify Discord Webhook Secret
Make sure `DISCORD_WEBHOOK_URL` is set in GitHub Secrets:
- Repository → Settings → Secrets and variables → Actions
- Should see: `DISCORD_WEBHOOK_URL`

### 2. Deploy
Push changes or manually trigger:
```bash
git add .
git commit -m "Add Discord alerting with Alertmanager"
git push origin main
```

### 3. Test
After deployment (~15 min):
```bash
# Get EC2 IP
cd infrastructure/dev
terraform output ec2_public_ip

# Test alert
ssh ec2-user@<EC2_IP>
stress --cpu 8 --timeout 600  # Wait 5 minutes for alert
```

### 4. Verify
Check Discord channel for alert notifications!

---

## Alert Summary

Your system will now send Discord notifications for:

| Alert | When | Duration | Severity |
|-------|------|----------|----------|
| NodeExporterDown | Metrics collection stopped | 2 min | 🔥 Critical |
| CAdvisorDown | Container metrics stopped | 2 min | 🔥 Critical |
| HighCPUUsage | CPU >80% | 5 min | ⚠️ Warning |
| HighMemoryUsage | Memory >85% | 5 min | ⚠️ Warning |
| LowDiskSpace | Disk <15% free | 5 min | ⚠️ Warning |

Plus resolved notifications when issues are fixed!

---

## Ports Reference

| Service | Port | Purpose |
|---------|------|---------|
| App | 80 | Node.js application |
| Grafana | 3000 | Dashboards |
| cAdvisor | 8080 | Container metrics |
| Prometheus | 9090 | Metrics & alerts |
| Alertmanager | 9093 | Alert management |
| Discord Proxy | 9094 | Internal (not exposed) |
| Node Exporter | 9100 | System metrics |

---

## Architecture

```
EC2 Instance
├── prometheus:9090
│   ├── Scrapes: node-exporter, cadvisor
│   ├── Evaluates: alert.rules.yml
│   └── Sends alerts to: alertmanager:9093
│
├── alertmanager:9093
│   ├── Receives: alerts from Prometheus
│   ├── Routes to: discord-proxy:9094
│   └── UI: http://<EC2_IP>:9093
│
├── discord-proxy:9094
│   ├── Receives: webhooks from Alertmanager
│   ├── Converts: to Discord embeds
│   └── Sends to: Discord webhook URL
│
├── grafana:3000 (visualization)
├── node-exporter:9100 (system metrics)
└── cadvisor:8080 (container metrics)
```

All running in Docker network: `monitoring`

---

## 🎉 You're All Set!

Your infrastructure now has:
- ✅ Complete monitoring (Prometheus + Grafana)
- ✅ Alert rules for critical issues
- ✅ Automatic Discord notifications
- ✅ Auto-deployment via CI/CD
- ✅ Auto-restart on boot

**No manual docker-compose needed** - everything deployed via your CI/CD pipeline!

---

For detailed documentation, see:
- **Quick Start**: `docs/DISCORD_ALERTING_QUICKSTART.md`
- **Full Guide**: `docs/ALERTING_SETUP.md`
- **Monitoring Reference**: `docs/MONITORING_QUICK_REF.md`
