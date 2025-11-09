# Infrastructure & Automation Runbook

This is the end‑to‑end guide for how the infrastructure, AMI (Packer), monitoring, and deployments work in this repo. It's focused on practical operations: what's automated, what secrets are needed and why, what gets triggered when, and how to verify or destroy cleanly.

If you're just joining the project, start here.

---

## Performance Statistics (From Zero to Production)

**Complete deployment time (from scratch):**
- Infrastructure deployment: **~8m 10s**
  - Includes: Terraform backend bootstrap, AMI build (if needed), EC2 + networking, monitoring stack, auto-redeploy service
- App deployment: **~1m 40s**
  - Docker build, ECR push, SSM deployment to EC2
- Discord Bot deployment: **~1m 39s**
  - Docker build, ECR push, SSM deployment to EC2

**Total time from zero to fully operational AWS infrastructure with monitoring and applications: ~10-12 minutes**

**Complete teardown:**
- Destroy all infrastructure: **~1m 54s**
  - Includes: EC2, networking, ECR (with force delete), S3 state bucket cleanup, DynamoDB lock table, AMI + snapshots

**Key advantage:** Fully automated end-to-end. Push to main branch and within 10 minutes you have a production-ready environment with monitoring, alerts, and both applications running. Single workflow dispatch destroys everything cleanly in under 2 minutes.

---

## What’s fully automated

- Terraform backend bootstrap (S3 state + DynamoDB lock) — auto-created on first deploy if missing.
- ECR repositories for the app and the Discord bot — managed by Terraform with safe destroy (`force_delete = true`).
- Team SSH key pairs — add a user’s public key in `tfvars`; Terraform creates the AWS key pair.
- AMI Build (Docker + SSM) — built only when Packer files change and when no AMI exists.
- Infrastructure deploy — Terraform apply for `infrastructure/dev` with remote backend.
- Monitoring stack — Prometheus, Alertmanager, Grafana, node‑exporter, cAdvisor, and a Discord webhook proxy, installed on EC2 via SSM.
- Auto‑redeploy systemd service — installs via SSM so the app can redeploy on instance boot.
- Status and notifications — Discord notifications for deploy/destroy/status.

All of the above is orchestrated by the GitHub Actions workflow at `.github/workflows/infra-makefile.yml` using a clean Makefile in `infrastructure/`.

---

## GitHub Actions workflow (high level)

Jobs and when they run:
- Quick Check (PRs): Terraform fmt/validate, TFLint. No deploy.
- Build AMI (main/manual deploy):
  - Uses a change detector to check if `infrastructure/packer/**` changed.
  - If yes, authenticates to AWS, restores Packer cache, and runs `make packer-build`.
- Deploy Everything (main/manual deploy):
  - Runs only if there are changes in `infrastructure/**`.
  - Deploys Terraform (`make deploy-testing`), then monitoring and auto‑redeploy service via SSM.
  - Posts success/failure notifications to Discord.
- Dispatch App/Bot: Triggers app and bot workflows only if their folders changed.
- Destroy (manual): Runs ordered teardown and posts Discord results.
- Check Status (manual): Reads Terraform outputs and EC2 state and posts to Discord.

Conditional execution uses `tj-actions/changed-files` so we skip expensive steps when nothing relevant changed.

---

## Packer build scenarios (how AMI is decided)

Two layers prevent unnecessary builds:

1) Change detection (workflow):
   - If nothing under `infrastructure/packer/**` changed in the commit, the AMI build job is skipped entirely.

2) Existence check (Makefile target `packer-build`):
   - If an AMI tagged `Name=team7-docker-ami-dev` already exists, the Makefile prints the AMI ID and skips building.
   - If no AMI exists, it runs `packer init` and `packer build` to create it.

How to force rebuild:
- Make a small change in the Packer files (e.g., a comment) so the workflow reruns the build, or
- Temporarily change the AMI name in the Packer template for a one‑off build, or
- Add (future enhancement) a `force_packer` workflow input to bypass the change check.

What the AMI contains:
- Amazon Linux 2023
- SSM Agent (enabled)
- Docker (enabled)

---

## Terraform backend bootstrap

- Code: `infrastructure/bootstrap/*.tf`
- Behavior: On first deploy, the Makefile checks if the S3 bucket exists. If not, it runs Terraform apply in `bootstrap/` to create:
  - S3 bucket: `team7-dev-tf-state` (versioning enabled, encryption, public access blocked)
  - DynamoDB table: `team7-dev-tf-lock`
- Backend for `infrastructure/dev` is configured to point at that bucket/table (remote state).

You don’t have to create these by hand; the workflow runs the Makefile targets which perform the checks and create them if needed.

---

## ECR repositories

- Code: `infrastructure/dev/ecr.tf`
- Repos: `team7-app` and `discord-bot`
- Features:
  - `force_delete = true` so `terraform destroy` succeeds even if images exist
  - Lifecycle policies to expire untagged images (keeps last N)

No manual setup required.

---

## Team SSH keys automation

- Code: `infrastructure/dev/keypair.tf`
- How it works:
  - Provide a map `ssh_public_keys` in your `*.tfvars` where key = username, value = public key string (recommended) or path to a local public key file.
  - Only valid entries (starting with `ssh-` and long enough) are used.
  - Terraform creates one AWS key pair per entry and tags them.

To add a member:
- Append their public key into the tfvars map and apply.

---

## Monitoring stack

- Script: `infrastructure/scripts/deploy_monitoring.sh`
- What it does:
  - Uploads Prometheus, Alertmanager, Grafana provisioning, dashboards, and a small Python Discord proxy to S3 under a prefix.
  - Uses AWS SSM to run a remote command on the EC2 instance, which downloads these files and starts Docker containers:
    - node‑exporter (9100), cAdvisor (8080), Prometheus (9090), Alertmanager (9093), Grafana (3000), Discord proxy (9094).
  - Uses `DISCORD_WEBHOOK_URL` for Alertmanager → Discord alerts via the proxy.

Endpoints (default):
- Prometheus: http://<public_ip>:9090
- Alertmanager: http://<public_ip>:9093
- Grafana: http://<public_ip>:3000 (admin/admin by default)
- Node Exporter: http://<public_ip>:9100/metrics
- cAdvisor: http://<public_ip>:8080

---

## Auto‑redeploy service

- Script: `infrastructure/scripts/install_redeploy_service.sh`
- Installs a systemd unit and script via SSM (pulled from S3) so the app re‑deploys automatically on instance boot.

---

## Required GitHub secrets (and why)

Set these in GitHub → Repository → Settings → Secrets and variables → Actions.

- AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY
  - Why: Authenticates the workflow to AWS for Terraform, Packer, SSM, ECR, EC2 queries.
  - Where used: All infra jobs via `aws-actions/configure-aws-credentials`.

- DISCORD_WEBHOOK_URL
  - Why: Sends deployment/destroy/status notifications and enables Alertmanager → Discord alerts through the proxy.
  - Where used: Custom Discord notify action; monitoring deployment script environment.

- DISCORD_BOT_TOKEN
  - Why: Lets the Discord bot authenticate to Discord APIs.
  - Where used: Bot build/deploy runtime (bot workflow and container).

- DISCORD_GUILD_ID
  - Why: Targets a specific Discord server for bot operations (e.g., channel lookups).
  - Where used: Bot runtime configuration.

- BOT_GITHUB_TOKEN (optional but useful)
  - Why: If the bot needs to call GitHub API beyond the default `GITHUB_TOKEN` permissions, this PAT can grant specific scopes.
  - Where used: Bot workflow or code paths that interact with GitHub.

- GIT_REPO (optional)
  - Why: Parameter to reference this repository from scripts or the bot without hard‑coding.
  - Where used: Any script/bot logic that clones or calls back to the repo.

Note: `GITHUB_TOKEN` is provided automatically by Actions — you don’t create it.

---

## Triggers and change detection

- AMI build runs only if Packer files changed in the commit AND no existing dev AMI found by Makefile.
- Infra deploy runs only if `infrastructure/**` changed.
- App workflow is dispatched only if `devop-2-main/**` changed; similarly for `discord-bot/**`.

This keeps CI fast and avoids unnecessary runs.

---

## Destroying everything

Use the manual workflow dispatch (action = `destroy`). It performs:
1. Terraform destroy for `infrastructure/dev` (uses remote backend).
2. S3 bucket cleanup (including versioned objects and delete markers), DynamoDB table deletion.
3. AMI and snapshot deletion.

Because ECR uses `force_delete = true`, repos are deleted even with images inside.

---

## Verification checklist after deploy

- Workflow logs show:
  - Build AMI: skipped or built, depending on changes/existence.
  - Deploy: Terraform apply OK, monitoring & redeploy service installed.
  - Discord: success message posted with instance ID and public IP.
- On the instance public IP:
  - App responds on configured port (Security Group allows 80 and 3000).
  - Prometheus 9090, Alertmanager 9093, Grafana 3000 accessible.

---

## Local/manual use (optional)

You don’t need to, but if you run locally:
- Terraform 1.13.4+, AWS CLI v2, Packer installed, jq available.
- `make deploy-testing` will bootstrap backend if needed and deploy dev infra.
- `make packer-build` builds the AMI if it’s missing.

On Windows PowerShell, export env vars like:
```
$env:AWS_ACCESS_KEY_ID = "..."
$env:AWS_SECRET_ACCESS_KEY = "..."
$env:AWS_REGION = "eu-central-1"
```

---

## Known assumptions

- Region is `eu-central-1` everywhere (Packer, Terraform, scripts).
- AMI name is fixed: `team7-docker-ami-dev` (fast rebuilds, easy detection).
- EC2 has IAM permissions for SSM; your AWS account has access to required services.

---

## Troubleshooting

- AMI build skipped unexpectedly:
  - Ensure a real change under `infrastructure/packer/**` or manually remove the existing AMI to trigger a rebuild.
- Terraform init complains about missing backend:
  - The bootstrap step should create it on first deploy; check Makefile logs in the deploy job.
- Destroy fails on S3 bucket:
  - Versioned objects may need multiple passes; the Makefile includes a deep cleanup with `jq` and `delete-objects`.
- No Discord notifications:
  - Verify `DISCORD_WEBHOOK_URL` is set and valid; check workflow logs for HTTP errors.
- Monitoring endpoints not reachable:
  - Confirm Security Group ports are open (80, 3000, 8080, 9090, 9093, 9100) and containers are running (SSM command logs in workflow).

---
