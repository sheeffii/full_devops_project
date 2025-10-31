# =============================================================================
# TEAM7 DEVOPS PIPELINE — CLEAN & ORGANIZED MAKEFILE
# =============================================================================
# Targets:
#   all                 → Full pipeline (Packer → Bootstrap → Dev)
#   bootstrap           → Create S3 bucket + DynamoDB lock table
#   deploy-dev-only     → Deploy dev/ only (assumes backend exists)
#   deploy-testing      → Bootstrap + dev (skip Packer)
#   full-deploy         → All + SSM connect
#   ec2-ssm-connect     → SSM session (auto-install plugin)
#   ec2-ssh-connect     → SSH via EIP
#   destroy             → Safe destroy (dev → bootstrap)
#   clean               → Remove local state
#   packer-build-prod   → (commented) Prod AMI with cleanup
# =============================================================================

.PHONY: all bootstrap deploy-testing deploy-dev-only destroy clean \
        packer-build full-deploy ec2-ssm-connect ec2-ssh-connect \
        install-ssm-plugin

# ─────────────────────────────────────────────────────────────────────────────
# CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────
BOOTSTRAP_DIR = bootstrap
TESTING_DIR   = dev
TFVARS        = example.tfvars
REGION        = eu-central-1

# ─────────────────────────────────────────────────────────────────────────────
# DEFAULT: FULL PIPELINE
# ─────────────────────────────────────────────────────────────────────────────
all: packer-build bootstrap deploy-dev-only

# ─────────────────────────────────────────────────────────────────────────────
# 1. PACKER: Build Docker-ready AMI
# ─────────────────────────────────────────────────────────────────────────────
packer-build:
	@echo "Building/Updating Packer AMI (overwrites existing)..."
	cd packer && packer init . && packer build -force packer-docker-ami.pkr.hcl
	@if [ -f packer/packer-manifest.json ]; then \
		if command -v jq >/dev/null 2>&1; then \
			AMI_ID=$$(jq -r '.builds[0].artifact_id' packer/packer-manifest.json | grep -o 'ami-[0-9a-f]\{8,17\}' | head -1); \
			if [ -n "$$AMI_ID" ]; then \
				echo "AMI ready! ID: $$AMI_ID"; \
			else \
				echo "AMI ready! (Check manifest: cat packer/packer-manifest.json | grep ami-)"; \
			fi; \
		else \
			echo "AMI ready! (Install 'jq' for auto-ID: sudo apt install jq)"; \
			echo "   Manual check: cat packer/packer-manifest.json | grep -o 'ami-[0-9a-f]\{8,17\}'"; \
		fi; \
		echo "Test: Launch EC2 from 'team7-docker-ami-dev' in Console, verify Docker/SSM."; \
	fi

# ─────────────────────────────────────────────────────────────────────────────
# 2. BOOTSTRAP: Create backend (S3 + DynamoDB)
# ─────────────────────────────────────────────────────────────────────────────
bootstrap:
	@echo "Bootstrapping backend..."
	cd $(BOOTSTRAP_DIR) && rm -rf .terraform .terraform.lock.hcl
	cd $(BOOTSTRAP_DIR) && terraform init -reconfigure -upgrade
	cd $(BOOTSTRAP_DIR) && terraform validate
	cd $(BOOTSTRAP_DIR) && terraform apply -auto-approve


# ─────────────────────────────────────────────────────────────────────────────
# 3. DEPLOY DEV ONLY
# ─────────────────────────────────────────────────────────────────────────────
deploy-dev-only:
	@echo "Deploying to dev/ only (skipping Packer & bootstrap)..."
	@DEV_ABS=$$(pwd)/$(TESTING_DIR); \
	echo "Debug: Using dev path $$DEV_ABS"; \
	mkdir -p $$DEV_ABS || true; \
	cd $$DEV_ABS && terraform init -reconfigure \
		-backend-config="bucket=team7-dev-tf-state" \
		-backend-config="key=dev/terraform.tfstate" \
		-backend-config="region=$(REGION)" \
		-backend-config="dynamodb_table=team7-dev-tf-lock"; \
	cd $$DEV_ABS && terraform validate; \
	cd $$DEV_ABS && terraform apply -var-file=$(TFVARS) -auto-approve; \
	echo "Dev deployment complete!"

# ─────────────────────────────────────────────────────────────────────────────
# COMPOSITE TARGETS
# ─────────────────────────────────────────────────────────────────────────────
deploy-testing:
	@echo "Deploying testing (bootstrap + dev; skipping Packer)..."
	@echo "Checking if bootstrap backend exists..."
	@if aws s3 ls s3://team7-dev-tf-state >/dev/null 2>&1; then \
		echo "✅ Bucket exists—skipping bootstrap!"; \
	else \
		echo "⚠️  Bucket missing—running bootstrap..."; \
		$(MAKE) bootstrap; \
	fi
	$(MAKE) deploy-dev-only

full-deploy: packer-build bootstrap deploy-dev-only ec2-ssm-connect
	@echo "Full deployment + SSM connection complete!"

# ─────────────────────────────────────────────────────────────────────────────
# CONNECT: SSM (preferred)
# ─────────────────────────────────────────────────────────────────────────────
ec2-ssm-connect:
	@echo "Preparing SSM connection..."
	@if ! command -v session-manager-plugin >/dev/null 2>&1; then \
		echo "SSM plugin not found — installing now..."; \
		curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb"; \
		sudo dpkg -i session-manager-plugin.deb; \
		rm -f session-manager-plugin.deb; \
		echo "SSM plugin installed successfully!"; \
	else \
		echo "SSM plugin already installed — skipping install."; \
	fi
	@echo "Connecting to EC2 via SSM..."
	@INSTANCE_ID=$$(cd $(TESTING_DIR) && terraform output -raw ec2_instance_id); \
	if [ -z "$$INSTANCE_ID" ]; then \
		echo "Error: No instance ID found—run deploy first"; \
		exit 1; \
	fi; \
	echo "Instance ID: $$INSTANCE_ID"; \
	aws ssm start-session --target $$INSTANCE_ID --region $(REGION)

# ─────────────────────────────────────────────────────────────────────────────
# CONNECT: SSH (via EIP)
# ─────────────────────────────────────────────────────────────────────────────
ec2-ssh-connect:
	@IP=$$(cd $(TESTING_DIR) && terraform output -raw ec2_public_ip); \
	ssh -i ~/.ssh/id_rsa ec2-user@$$IP

# ─────────────────────────────────────────────────────────────────────────────
# SSM PLUGIN: Install (one-time)
# ─────────────────────────────────────────────────────────────────────────────
install-ssm-plugin:
	@echo "Installing AWS SSM Session Manager plugin..."
	@curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb" && \
	sudo dpkg -i session-manager-plugin.deb && \
	rm session-manager-plugin.deb && \
	echo "SSM plugin installed! Verify: session-manager-plugin"

# ─────────────────────────────────────────────────────────────────────────────
# DESTROY: Safe, ordered
# ─────────────────────────────────────────────────────────────────────────────
# ─────────────────────────────────────────────────────────────────────────────
# DESTROY: Safe, ordered, NO backend.tf required
# ─────────────────────────────────────────────────────────────────────────────
# ─────────────────────────────────────────────────────────────────────────────
# DESTROY: Uses saved bucket from .state-bucket file
# ─────────────────────────────────────────────────────────────────────────────
destroy:
	@echo "Destroy all? (y/n)" && read ans && [ $${ans:-n} = y ] || exit 0

	# ---- DEV -------------------------------------------------
	@D=$$(pwd)/$(TESTING_DIR); \
	if [ ! -d "$$D" ]; then \
		echo "ERROR: $(TESTING_DIR)/ directory not found!"; exit 1; \
	fi; \
	echo "Destroying dev/ ($$D)"; \
	cd $$D && rm -rf .terraform .terraform.lock.hcl; \
	cd $$D && terraform init -reconfigure \
		-backend-config="bucket=team7-dev-tf-state" \
		-backend-config="key=dev/terraform.tfstate" \
		-backend-config="region=$(REGION)" \
		-backend-config="dynamodb_table=team7-dev-tf-lock" \
		2>/dev/null || true; \
	cd $$D && terraform destroy -var-file=$(TFVARS) -auto-approve

	# ---- BOOTSTRAP -------------------------------------------
	@B=$$(pwd)/$(BOOTSTRAP_DIR); \
	if [ ! -d "$$B" ]; then \
		echo "ERROR: $(BOOTSTRAP_DIR)/ directory not found!"; exit 1; \
	fi; \
	echo "Destroying bootstrap/ ($$B)"; \
	cd $$B && rm -rf .terraform .terraform.lock.hcl; \
	cd $$B && terraform init -reconfigure 2>/dev/null || true; \
	cd $$B && terraform destroy -auto-approve
# ─────────────────────────────────────────────────────────────────────────────
# CLEAN: Local state & cache
# ─────────────────────────────────────────────────────────────────────────────
# ─────────────────────────────────────────────────────────────────────────────
# CLEAN: Remove local Terraform cache & state (preserves .tf source files)
# ─────────────────────────────────────────────────────────────────────────────
clean:
	@echo "🧹 Clean local Terraform cache and state files? (y/n)" && \
	read ans && [ "$${ans:-n}" = "y" ] || (echo "Aborted."; exit 0)

	@echo "→ Cleaning $(BOOTSTRAP_DIR)/..."
	rm -rf $(BOOTSTRAP_DIR)/.terraform
	rm -f $(BOOTSTRAP_DIR)/.terraform.lock.hcl
	rm -f $(BOOTSTRAP_DIR)/terraform.tfstate
	rm -f $(BOOTSTRAP_DIR)/terraform.tfstate.backup

	@echo "→ Cleaning $(TESTING_DIR)/..."
	rm -rf $(TESTING_DIR)/.terraform
	rm -f $(TESTING_DIR)/.terraform.lock.hcl
	rm -f $(TESTING_DIR)/terraform.tfstate
	rm -f $(TESTING_DIR)/terraform.tfstate.backup

	@echo "→ Cleaning packer/..."
	rm -f packer/packer-manifest.json

	@echo "✅ Clean complete. All .tf source files preserved."

# ─────────────────────────────────────────────────────────────────────────────
# PROD MODE: Uncomment below for timestamped AMIs with auto-cleanup
# ─────────────────────────────────────────────────────────────────────────────
# .PHONY: packer-build-prod
# packer-build-prod:
# 	@echo "Building Timestamped Packer AMI (prod mode with cleanup)..."
# 	cd packer && packer init . && packer build -force packer-docker-ami.pkr.hcl
# 	@echo "Cleaning up old AMIs (older than 7 days; keeping last 2 newest of those)..."
# 	@SEVEN_DAYS_AGO=$$(date -d "7 days ago" +%Y-%m-%dT00:00:00Z 2>/dev/null || echo "1900-01-01T00:00:00Z"); \
# 	OLD_IDS=$$(aws ec2 describe-images \
# 		--owners self \
# 		--region eu-central-1 \
# 		--filters "Name=tag:BuiltBy,Values=packer" "Name=name,Values=docker-ready-ami*" \
# 		--query 'Images[?CreationDate < `'"$$SEVEN_DAYS_AGO"'`].{ID:ImageId,Date:CreationDate}' \
# 		--output text 2>/dev/null | sort -k2 | head -n -2 | cut -f1 | tr '\n' ' '); \
# 	if [ -z "$$OLD_IDS" ]; then \
# 		echo "No old AMIs to delete."; \
# 	else \
# 		echo "Deleting old AMIs: $$OLD_IDS"; \
# 		for ami in $$OLD_IDS; do aws ec2 deregister-image --image-id $$ami --region eu-central-1 || true; done; \
# 	fi
# 	@echo "Prod build and cleanup complete!"