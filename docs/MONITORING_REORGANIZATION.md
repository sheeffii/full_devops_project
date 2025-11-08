# 📁 Monitoring Files Reorganization

## Summary

All monitoring-related files have been reorganized into a centralized `infrastructure/monitoring/` directory for better project structure and maintainability.

## What Changed

### New Structure

```
infrastructure/monitoring/
├── configs/
│   ├── alert.rules.yml          # Prometheus alert definitions
│   ├── alertmanager.yml         # Alertmanager routing config
├── grafana-dashboards/
│   └── 1860_rev42.json         # Node Exporter Full dashboard
├── grafana-provisioning/
│   ├── datasources/
│   │   └── prometheus.yml      # Prometheus datasource
│   └── dashboards/
│       └── dashboard.yml       # Dashboard provisioning
└── README.md                   # Monitoring documentation
```

### Files Moved

| Old Location | New Location |
|--------------|--------------|
| `alert.rules.yml` | `infrastructure/monitoring/configs/alert.rules.yml` |
| `alertmanager.yml` | `infrastructure/monitoring/configs/alertmanager.yml` |
| `grafana-dashboards/` | `infrastructure/monitoring/grafana-dashboards/` |
| `grafana-provisioning/` | `infrastructure/monitoring/grafana-provisioning/` |

### Files Updated

All references to the old paths have been updated in:

✅ `infrastructure/scripts/deploy_monitoring.sh`
✅ `.github/workflows/infra-makefile.yml`
✅ `docs/ARCHITECTURE.md`
✅ `docs/ALERTING_SETUP.md`
✅ `docs/DISCORD_ALERTING_QUICKSTART.md`
✅ `docs/MONITORING_QUICK_REF.md`
✅ `ALERTING_IMPLEMENTATION.md`

### New Files Created

✅ `infrastructure/monitoring/README.md` - Monitoring documentation
✅ `infrastructure/monitoring/configs/prometheus.yml` - Local dev config
✅ `.gitignore` - Ignore local monitoring configs

## Benefits

1. **Better Organization**: All monitoring files in one logical location
2. **Cleaner Root**: Root directory is now cleaner and more organized
3. **Easier Navigation**: Clear separation between infrastructure and application code
4. **Scalability**: Easy to add more monitoring configs in the future
5. **Consistency**: Follows infrastructure-as-code best practices

## How It Works Now

### CI/CD Deployment

When deploying via GitHub Actions:

1. Workflow triggers on infrastructure changes
2. `deploy_monitoring.sh` reads configs from `infrastructure/monitoring/configs/`
3. Uploads to S3
4. EC2 downloads and deploys

### Local Development

For local testing:

```bash
cd infrastructure/monitoring

# Start monitoring stack
docker-compose up -d

# Access services
# Prometheus: http://localhost:9090
# Alertmanager: http://localhost:9093
# Grafana: http://localhost:3000
```

### File Paths

All scripts now reference the new structure:

**Deployment Script** (`infrastructure/scripts/deploy_monitoring.sh`):
```bash
ALERT_RULES_PATH="${REPO_ROOT}/infrastructure/monitoring/configs/alert.rules.yml"
ALERTMANAGER_CONFIG_PATH="${REPO_ROOT}/infrastructure/monitoring/configs/alertmanager.yml"
GRAFANA_PROVISIONING_DIR="${REPO_ROOT}/infrastructure/monitoring/grafana-provisioning"
GRAFANA_DASHBOARDS_DIR="${REPO_ROOT}/infrastructure/monitoring/grafana-dashboards"
```

**GitHub Workflow** (`.github/workflows/infra-makefile.yml`):
```yaml
paths:
  - 'infrastructure/**'  # Includes monitoring changes
```

## Next Steps

### For Existing Deployments

If you have an existing deployment:

1. **Commit the changes**:
   ```bash
   git add .
   git commit -m "Reorganize monitoring files into infrastructure/monitoring/"
   git push origin main
   ```

2. **Automatic redeployment**: The workflow will pick up changes and redeploy with new paths

3. **No manual intervention needed**: Paths are resolved dynamically during deployment

### For New Contributors

1. All monitoring configs are in `infrastructure/monitoring/configs/`
2. To modify alerts: Edit `infrastructure/monitoring/configs/alert.rules.yml`
3. To modify alerting: Edit `infrastructure/monitoring/configs/alertmanager.yml`
4. Local testing: Use `infrastructure/monitoring/docker-compose.yml`

## Validation

All references have been updated and tested:

- ✅ Deployment scripts point to new locations
- ✅ Workflow paths simplified (monitors entire `infrastructure/` folder)
- ✅ Documentation updated across all files
- ✅ Docker compose uses correct volume mounts
- ✅ Alertmanager config references updated
- ✅ README files created for guidance

---

**Date**: November 8, 2025
**Status**: Complete ✅
**Impact**: Non-breaking change (automatic path resolution)
