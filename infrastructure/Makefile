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
#   destroy             → Safe destroy (dev → bootstrap + AMI cleanup)
#   clean               → Remove local state
#   packer-build-prod   → (commented) Prod AMI with cleanup
# =============================================================================

.PHONY: all bootstrap deploy-testing deploy-dev-only destroy clean \
        packer-build full-deploy ec2-ssm-connect ec2-ssh-connect \
        install-ssm-plugin

# ─────────────────────────────────────────────────────────────────────────────
# CONFIGURATION (Override in CI: ENV=staging BUCKET=my-bucket)
# ─────────────────────────────────────────────────────────────────────────────
ENV             ?= dev
BUCKET          ?= team7-$(ENV)-tf-state
STATE_KEY       ?= $(ENV)/terraform.tfstate
LOCK_TABLE      ?= team7-$(ENV)-tf-lock
TFVARS          = example.tfvars
TFVARS_PATH     = $(TESTING_DIR)/$(TFVARS)
REGION          = eu-central-1
BOOTSTRAP_DIR   = bootstrap
TESTING_DIR     = dev
AUTO            ?= no  # For non-interactive (e.g., AUTO=yes make destroy)

# ─────────────────────────────────────────────────────────────────────────────
# DEFAULT: FULL PIPELINE
# ─────────────────────────────────────────────────────────────────────────────
all: packer-build deploy-testing

# ─────────────────────────────────────────────────────────────────────────────
# 1. PACKER: Build Docker-ready AMI (skip if exists)
# ─────────────────────────────────────────────────────────────────────────────
packer-build:
	@echo "🚀 Building/Updating Packer AMI (ENV: $(ENV))..."
	@rm -f packer/packer-manifest.json
	@echo "🔍 Checking for existing AMI with tag 'team7-docker-ami-$(ENV)'..."
	@AMI_ID=$$(aws ec2 describe-images --owners self \
		--filters "Name=tag:Name,Values=team7-docker-ami-$(ENV)" \
		--query 'Images[0].ImageId' --output text --region $(REGION) 2>/dev/null); \
	if [ -n "$$AMI_ID" ] && [ "$$AMI_ID" != "None" ]; then \
		echo "✅ Existing AMI found: $$AMI_ID — skipping Packer build."; \
	else \
		echo "❌ No AMI found — starting Packer build..."; \
		cd packer && packer init . && packer build -force packer-docker-ami.pkr.hcl; \
	fi; \
	echo "✅ Packer build finished. AMI should be ready."

# ─────────────────────────────────────────────────────────────────────────────
# 2. BOOTSTRAP: Create backend (S3 + DynamoDB)
# ─────────────────────────────────────────────────────────────────────────────
bootstrap:
	@echo "🚀 Bootstrapping Terraform backend (ENV: $(ENV), Bucket: $(BUCKET))..."
	@if aws s3 ls s3://$(BUCKET) >/dev/null 2>&1; then \
		echo "✅ Backend exists (bucket $(BUCKET), lock table $(LOCK_TABLE)) — skipping bootstrap!"; \
	else \
		echo "⚠️ Backend missing — running bootstrap..."; \
		( \
			cd $(BOOTSTRAP_DIR); \
			rm -rf .terraform .terraform.lock.hcl; \
			terraform init -reconfigure -upgrade; \
			terraform validate; \
			terraform apply -auto-approve; \
		); \
		echo "✅ Created successfully — bucket $(BUCKET), table $(LOCK_TABLE)."; \
	fi

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
	cd $$DEV_ABS && if [ ! -f $(TFVARS) ]; then echo "# Default vars" > $(TFVARS); echo "Created missing $(TFVARS)"; fi; \
	cd $$DEV_ABS && echo "Debug: tfvars in dev/: "; ls -la $(TFVARS); \
	cd $$DEV_ABS && terraform apply -var-file=$(TFVARS) -auto-approve; \
	echo "Dev deployment complete!"

# ─────────────────────────────────────────────────────────────────────────────
# COMPOSITE TARGETS
# ─────────────────────────────────────────────────────────────────────────────
deploy-testing:
	@echo "🚀 Deploying testing (bootstrap + dev; skipping Packer)..."
	$(MAKE) bootstrap
	$(MAKE) deploy-dev-only


full-deploy: packer-build deploy-testing ec2-ssm-connect
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
destroy:
	@if [ "$(AUTO)" = "yes" ]; then \
		echo "AUTO=yes—destroying all..."; \
	else \
		echo "Destroy all? (y/n)" && read ans && [ "$$ans" = "y" ] || exit 0; \
	fi

	# ---- DEV -------------------------------------------------
	@D=$$(pwd)/$(TESTING_DIR); \
	if [ ! -d "$$D" ]; then \
		echo "ERROR: $(TESTING_DIR)/ directory not found!"; exit 1; \
	fi; \
	echo "Destroying dev/ ($$D)"; \
	cd $$D && rm -rf .terraform .terraform.lock.hcl; \
	cd $$D && terraform init -reconfigure \
		-backend-config="bucket=$(BUCKET)" \
		-backend-config="key=$(STATE_KEY)" \
		-backend-config="region=$(REGION)" \
		-backend-config="dynamodb_table=$(LOCK_TABLE)" \
		2>/dev/null || true; \
	cd $$D && terraform destroy -var-file=$(TFVARS) -auto-approve

# ---- BOOTSTRAP (conditional) -------------------------------------------
	@echo "🗑️ Destroying Terraform bootstrap resources..."
	@if aws s3 ls s3://$(BUCKET) >/dev/null 2>&1; then \
		echo "→ Clearing S3 contents first (for safe force-delete)..."; \
		aws s3 rm s3://$(BUCKET) --recursive --region $(REGION) || true; \
		echo "→ Clearing old S3 versions/markers (handles versioning ghosts)..."; \
		# Batch delete all versions + markers (fixed JMESPath query for concatenation) \
		aws s3api delete-objects --bucket $(BUCKET) --delete "$$(aws s3api list-object-versions --bucket $(BUCKET) --region $(REGION) --query '{Objects: Versions[*].{Key:Key,VersionId:VersionId} + DeleteMarkers[*].{Key:Key,VersionId:VersionId}}' --output json)" --region $(REGION) >/dev/null 2>/dev/null || true; \
		echo "→ Deleting S3 bucket $(BUCKET)..."; \
		aws s3 rb s3://$(BUCKET) --force --region $(REGION) || echo "  ⚠️ Bucket delete failed (check versions manually)."; \
	else \
		echo "⚠️ S3 bucket $(BUCKET) not found, skipping."; \
	fi; \
	if aws dynamodb describe-table --table-name $(LOCK_TABLE) --region $(REGION) >/dev/null 2>&1; then \
		echo "→ Clearing any DynamoDB locks (unblocks delete)..."; \
		aws dynamodb delete-item --table-name $(LOCK_TABLE) --key '{"LockID":{"S":"team7-dev-tf-state/dev/terraform.tfstate-md5"}}' --region $(REGION) || true; \
		echo "→ Deleting DynamoDB table $(LOCK_TABLE)..."; \
		aws dynamodb delete-table --table-name $(LOCK_TABLE) --region $(REGION) >/dev/null 2>/dev/null || echo "  ⚠️ Table delete failed (retry after locks clear)."; \
	else \
		echo "⚠️ DynamoDB table $(LOCK_TABLE) not found, skipping."; \
	fi; \
	echo "→ Cleaning local bootstrap files..."; \
	rm -rf $(BOOTSTRAP_DIR)/.terraform* $(BOOTSTRAP_DIR)/terraform.tfstate* 2>/dev/null || true; \
	echo "✅ Bootstrap destroyed successfully."



# ---- PACKER AMI CLEANUP --------------------------------------------------
	@echo "🚀 Destroying Packer AMI and associated snapshots for ENV: $(ENV)..."
	@AMI_ID=$$(aws ec2 describe-images --owners self \
		--filters "Name=tag:Name,Values=team7-docker-ami-$(ENV)" \
		--query 'Images[0].ImageId' --output text --region $(REGION) 2>/dev/null); \
	if [ -n "$$AMI_ID" ] && [ "$$AMI_ID" != "None" ]; then \
		echo "Found AMI: $$AMI_ID — deregistering..."; \
		SNAPSHOTS=$$(aws ec2 describe-images --image-ids $$AMI_ID --region $(REGION) \
			--query 'Images[0].BlockDeviceMappings[].Ebs.SnapshotId' --output text 2>/dev/null); \
		aws ec2 deregister-image --image-id $$AMI_ID --region $(REGION); \
		for snap in $$SNAPSHOTS; do \
			if [ -n "$$snap" ] && [ "$$snap" != "None" ]; then \
				echo "Deleting snapshot: $$snap"; \
				aws ec2 delete-snapshot --snapshot-id $$snap --region $(REGION) || true; \
			fi; \
		done; \
		echo "✅ AMI and snapshots deleted."; \
	else \
		echo "No Packer AMI found for $(ENV) — skipping cleanup."; \
	fi

# ─────────────────────────────────────────────────────────────────────────────
# CLEAN: Local state & cache
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
	rm -f $(TFVARS_PATH)  # Clean tfvars too if generated

	@echo "→ Cleaning packer/..."
	rm -f packer/packer-manifest.json
#	rm -f packer/.packer-hash   Clean hash file

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

destroy-bootstrap:
	@echo "🗑️ Destroying Terraform bootstrap resources..."
	@if aws s3 ls s3://$(BUCKET) >/dev/null 2>&1; then \
		echo "→ Deleting S3 bucket $(BUCKET)..."; \
		aws s3 rb s3://$(BUCKET) --force --region $(REGION) || true; \
	else \
		echo "⚠️ S3 bucket $(BUCKET) not found, skipping."; \
	fi; \
	if aws dynamodb describe-table --table-name $(LOCK_TABLE) --region $(REGION) >/dev/null 2>&1; then \
		echo "→ Deleting DynamoDB table $(LOCK_TABLE)..."; \
		aws dynamodb delete-table --table-name $(LOCK_TABLE) --region $(REGION) >/dev/null 2>&1 || true; \
	else \
		echo "⚠️ DynamoDB table $(LOCK_TABLE) not found, skipping."; \
	fi; \
	echo "→ Cleaning local bootstrap files..."; \
	rm -rf $(BOOTSTRAP_DIR)/.terraform* $(BOOTSTRAP_DIR)/terraform.tfstate* 2>/dev/null || true; \
	echo "✅ Bootstrap destroyed successfully."
