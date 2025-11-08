# Discord Alerting - Quick Setup Guide

## ✅ What's Already Done

Your alerting system is **fully configured** in code! Here's what happens automatically:

1. **Alert Rules**: 5 alerts defined in `infrastructure/monitoring/configs/alert.rules.yml`
2. **Alertmanager**: Configured in `infrastructure/monitoring/configs/alertmanager.yml` 
3. **Discord Proxy**: Python script converts alerts to Discord embeds
4. **CI/CD Integration**: Deploys everything automatically

## 🚀 How to Enable (One-Time Setup)

### Step 1: Get Discord Webhook URL

1. Open your Discord server
2. Go to **Server Settings** → **Integrations** → **Webhooks**
3. Click **New Webhook**
4. Name it "Prometheus Alerts" (or whatever you want)
5. Select the channel for alerts
6. Click **Copy Webhook URL**

### Step 2: Add to GitHub Secrets

Your webhook URL is **already configured** in GitHub Secrets as `DISCORD_WEBHOOK_URL`! 

To update or verify:
1. Go to your GitHub repo: https://github.com/sheeffii/full_devops_project
2. Settings → Secrets and variables → Actions
3. Check if `DISCORD_WEBHOOK_URL` exists
4. If not, click **New repository secret**:
   - Name: `DISCORD_WEBHOOK_URL`
   - Value: `https://discord.com/api/webhooks/YOUR/WEBHOOK/URL`

### Step 3: Deploy (Automatic!)

**Option A: Push infrastructure changes**
```bash
git add .
git commit -m "Enable Discord alerting"
git push origin main
```

**Option B: Manual trigger**
1. Go to Actions → Infrastructure CI/CD
2. Click "Run workflow"
3. Select action: `deploy`
4. Click "Run workflow"

The deployment script will automatically:
- ✅ Deploy Prometheus with alert rules
- ✅ Deploy Alertmanager 
- ✅ Deploy Discord webhook proxy
- ✅ Configure all connections
- ✅ Start monitoring

### Step 4: Test It!

After deployment completes (~15 minutes):

```bash
# Get your EC2 IP from GitHub Actions output or Terraform:
cd infrastructure/dev
terraform output ec2_public_ip

# SSH to EC2
ssh ec2-user@<EC2_IP>

# Trigger a test alert (high CPU)
stress --cpu 8 --timeout 600
```

Wait 5 minutes → You should see a Discord notification! 🎉

---

## 📊 What You'll See in Discord

### Alert Firing

```
🔥 CRITICAL: HighCPUUsage

Summary: High CPU usage detected
Instance: ec2-node
Severity: WARNING  
Status: FIRING
Description: CPU usage on ec2-node is above 80% (current value: 92.1%)

Environment: production
```

### Alert Resolved

```
✅ RESOLVED: HighCPUUsage

Summary: High CPU usage detected
Instance: ec2-node
Status: RESOLVED
Description: CPU usage on ec2-node is above 80% (current value: 92.1%)
```

---

## 🔍 Verify Setup

After deployment, check these URLs:

| Service | URL | What to Check |
|---------|-----|---------------|
| **Prometheus** | `http://<EC2_IP>:9090/alerts` | Shows all alerts (should see 5) |
| **Alertmanager** | `http://<EC2_IP>:9093` | Shows active alerts |
| **Grafana** | `http://<EC2_IP>:3000` | Dashboards (login: admin/admin) |

---

## 🎯 Configured Alerts

| Alert | Condition | Duration | What It Means |
|-------|-----------|----------|---------------|
| **NodeExporterDown** | Service unreachable | 2 min | Metrics collection stopped |
| **HighCPUUsage** | CPU >80% | 5 min | Server overloaded |
| **HighMemoryUsage** | Memory >85% | 5 min | Running out of RAM |
| **LowDiskSpace** | Disk <15% free | 5 min | Need to clean up disk |
| **CAdvisorDown** | Service unreachable | 2 min | Container metrics stopped |

---

## 🛠️ Troubleshooting

### Not receiving Discord notifications?

**Check 1: Webhook URL configured?**
```bash
# In GitHub Actions logs, look for:
# "⚠️ WARNING: DISCORD_WEBHOOK_URL not set"
```

**Check 2: Discord proxy running?**
```bash
ssh ec2-user@<EC2_IP>
sudo docker ps | grep discord-proxy

# Should show: discord-proxy (Up X minutes)
```

**Check 3: Test manually**
```bash
# Send test notification
curl -X POST http://<EC2_IP>:9093/api/v1/alerts \
  -H "Content-Type: application/json" \
  -d '[{
    "labels": {"alertname":"TestAlert","severity":"info"},
    "annotations": {"summary":"Test notification"}
  }]'

# Check Discord channel - should receive message
```

**Check 4: Logs**
```bash
# Discord proxy logs
sudo docker logs discord-proxy

# Alertmanager logs  
sudo docker logs alertmanager

# Prometheus logs
sudo docker logs prometheus
```

### Alerts not firing?

**Check Prometheus:**
1. Open `http://<EC2_IP>:9090/alerts`
2. Verify alerts are loaded (should see 5 alerts)
3. Check their status (Inactive/Pending/Firing)

**Check targets:**
1. Open `http://<EC2_IP>:9090/targets`
2. All targets should show "UP"
3. If DOWN, check Docker containers

---

## 📝 Configuration Files

| File | Purpose | Location |
|------|---------|----------|
| `alert.rules.yml` | Alert definitions | `infrastructure/monitoring/configs/` |
| `alertmanager.yml` | Routing config | `infrastructure/monitoring/configs/` |
| `discord-webhook-proxy.py` | Discord integration | `infrastructure/scripts/` |
| `deploy_monitoring.sh` | Deployment script | `infrastructure/scripts/` |

---

## 🔄 Update Alerts

To add/modify alerts:

1. Edit `infrastructure/monitoring/configs/alert.rules.yml`:
```yaml
- alert: MyNewAlert
  expr: my_metric > 100
  for: 2m
  labels:
    severity: warning
  annotations:
    summary: "My alert fired"
    description: "Details here"
```

2. Push to GitHub:
```bash
git add infrastructure/monitoring/configs/alert.rules.yml
git commit -m "Add new alert"
git push origin main
```

3. Automatic deployment updates Prometheus with new rules!

---

## ✨ Next Steps

- [ ] Test all alerts by simulating conditions
- [ ] Customize alert thresholds for your workload
- [ ] Add application-specific alerts (app response time, error rate)
- [ ] Set up alert silencing for maintenance windows
- [ ] Configure on-call rotations in Alertmanager

---

**Need help?** Check `docs/ALERTING_SETUP.md` for detailed documentation!
