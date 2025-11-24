# Makefile for Video Generation Server Management
# Centralizes all deployment and management commands

.PHONY: help deploy start stop status ssh destroy terraform-plan ansible-only

# Default target
.DEFAULT_GOAL := help

# Colors for output
CYAN := \033[0;36m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

help: ## Show this help message
	@echo "$(CYAN)Video Generation Server - Management Commands$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "$(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Common workflows:$(NC)"
	@echo "  1. First time:  make deploy"
	@echo "  2. Daily use:   make start && make ssh"
	@echo "  3. When done:   make stop"
	@echo ""

deploy: ## Complete deployment (Terraform + Ansible)
	@echo "$(CYAN)🚀 Starting complete deployment...$(NC)"
	@cd ansible && ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventory.yml deploy.yml

start: ## Start the server if stopped
	@echo "$(CYAN)▶️  Starting server...$(NC)"
	@cd ansible && ansible-playbook deploy.yml --tags instance

stop: ## Stop the server to save costs
	@echo "$(YELLOW)⏸  Stopping server...$(NC)"
	@cd terraform && \
		INSTANCE_ID=$$(terraform output -raw instance_id 2>/dev/null) && \
		aws ec2 stop-instances \
			--instance-ids $$INSTANCE_ID \
			--region us-east-2 \
			--profile bruno-admin-revalida-aws && \
		echo "$(GREEN)✅ Server stopped$(NC)"

status: ## Show server status
	@echo "$(CYAN)📊 Server Status:$(NC)"
	@cd terraform && \
		INSTANCE_ID=$$(terraform output -raw instance_id 2>/dev/null) && \
		STATE=$$(aws ec2 describe-instances \
			--instance-ids $$INSTANCE_ID \
			--region us-east-2 \
			--profile bruno-admin-revalida-aws \
			--query 'Reservations[0].Instances[0].State.Name' \
			--output text) && \
		IP=$$(terraform output -raw public_ip 2>/dev/null) && \
		TYPE=$$(terraform output -raw instance_type 2>/dev/null) && \
		echo "  Instance ID: $$INSTANCE_ID" && \
		echo "  State:       $$STATE" && \
		echo "  IP:          $$IP" && \
		echo "  Type:        $$TYPE"

ssh: ## SSH into the server
	@cd terraform && \
		IP=$$(terraform output -raw public_ip 2>/dev/null) && \
		ssh -i ~/.ssh/id_rsa ubuntu@$$IP

terraform-plan: ## Show what Terraform will change
	@echo "$(CYAN)📋 Terraform Plan:$(NC)"
	@cd terraform && terraform plan

terraform-apply: ## Apply Terraform changes only
	@echo "$(CYAN)🔧 Applying Terraform changes...$(NC)"
	@cd terraform && terraform apply

ansible-only: ## Run Ansible configuration only (no Terraform)
	@echo "$(CYAN)🔧 Running Ansible configuration...$(NC)"
	@cd ansible && \
		ANSIBLE_HOST_KEY_CHECKING=False \
		ansible-playbook -i inventory.yml playbook.yml -v

config: ansible-only ## Alias for ansible-only

destroy: ## Destroy all infrastructure (WARNING: DESTRUCTIVE!)
	@echo "$(RED)⚠️  WARNING: This will destroy all infrastructure!$(NC)"
	@echo "$(RED)Press Ctrl+C to cancel, or wait 5 seconds to continue...$(NC)"
	@sleep 5
	@cd terraform && terraform destroy

logs: ## Show Ansible logs from last deployment
	@tail -f /tmp/ansible-deploy.log 2>/dev/null || echo "No logs found"

outputs: ## Show all Terraform outputs
	@cd terraform && terraform output

video-status: ## Show detailed server status (requires server running)
	@cd terraform && \
		IP=$$(terraform output -raw public_ip 2>/dev/null) && \
		ssh -i ~/.ssh/id_rsa ubuntu@$$IP "video-status"

download-models: ## Download all 3 main models (HoloCine, HunyuanVideo, Wan 2.2)
	@echo "$(CYAN)📥 Downloading main AI models...$(NC)"
	@echo "$(YELLOW)⚠️  This will download ~75GB and take 30-60 minutes$(NC)"
	@cd ansible && \
		ANSIBLE_HOST_KEY_CHECKING=False \
		ansible-playbook -i inventory.yml playbook.yml --tags download-models

download-model: ## Download a specific model (usage: make download-model MODEL=tencent/HunyuanVideo)
	@if [ -z "$(MODEL)" ]; then \
		echo "$(RED)Error: MODEL not specified$(NC)"; \
		echo "Usage: make download-model MODEL=tencent/HunyuanVideo"; \
		exit 1; \
	fi
	@cd terraform && \
		IP=$$(terraform output -raw public_ip 2>/dev/null) && \
		ssh -i ~/.ssh/id_rsa ubuntu@$$IP "download-model $(MODEL)"

sync-videos: ## Sync videos from server to local machine
	@echo "$(CYAN)📥 Syncing videos from server...$(NC)"
	@mkdir -p ~/Videos/revalida
	@cd terraform && \
		IP=$$(terraform output -raw public_ip 2>/dev/null) && \
		rsync -avz --progress --ignore-existing -e "ssh -i ~/.ssh/id_rsa" \
			ubuntu@$$IP:/mnt/output/ ~/Videos/revalida/ && \
		echo "$(GREEN)✅ Videos synced to ~/Videos/revalida/$(NC)"

setup-auto-sync: ## Setup automatic video sync (runs every 5 minutes)
	@echo "$(CYAN)⚙️  Setting up automatic video sync...$(NC)"
	@(crontab -l 2>/dev/null | grep -v "revalida-video-sync"; \
		echo "*/5 * * * * cd $(PWD) && make sync-videos >> /tmp/revalida-sync.log 2>&1") | crontab -
	@echo "$(GREEN)✅ Auto-sync configured (every 5 minutes)$(NC)"
	@echo "$(YELLOW)Logs: /tmp/revalida-sync.log$(NC)"

remove-auto-sync: ## Remove automatic video sync
	@echo "$(YELLOW)Removing automatic video sync...$(NC)"
	@crontab -l 2>/dev/null | grep -v "revalida-video-sync" | crontab -
	@echo "$(GREEN)✅ Auto-sync removed$(NC)"

# Development helpers
init: ## Initialize Terraform
	@cd terraform && terraform init

validate: ## Validate Terraform configuration
	@cd terraform && terraform validate

fmt: ## Format Terraform files
	@cd terraform && terraform fmt -recursive

clean: ## Clean temporary files
	@echo "$(YELLOW)🧹 Cleaning temporary files...$(NC)"
	@find . -name "*.retry" -delete
	@find . -name ".terraform.lock.hcl" -delete
	@rm -f terraform/tfplan
	@echo "$(GREEN)✅ Clean complete$(NC)"

# Git helpers
commit: ## Git commit with standardized message
	@git add .
	@git status
	@echo "$(CYAN)Enter commit message:$(NC)"
	@read msg; git commit -m "$$msg"

push: commit ## Commit and push to GitHub
	@git push origin main
