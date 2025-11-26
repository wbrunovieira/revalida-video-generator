# Makefile for Video Generation Server Management
# Centralizes all deployment and management commands

.PHONY: help deploy start start-g5 start-p3dn stop status ssh destroy terraform-plan ansible-only

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

start: ## Start the server (interactive instance selection)
	@echo "$(CYAN)▶️  Starting server...$(NC)"
	@echo ""
	@echo "$(YELLOW)Select instance type:$(NC)"
	@echo ""
	@echo "  $(GREEN)1)$(NC) g5.12xlarge  - 4x A10G (24GB each) - ~$$1.70/h spot"
	@echo "     $(CYAN)Best for: Ovi, HunyuanVideo, HoloCine, CogVideoX$(NC)"
	@echo ""
	@echo "  $(GREEN)2)$(NC) p3dn.24xlarge - 8x V100 (32GB each) - ~$$10/h spot"
	@echo "     $(CYAN)Best for: LongCat-Video (requires 32GB+ VRAM/GPU)$(NC)"
	@echo ""
	@read -p "Choice [1-2, default=1]: " choice; \
	case "$$choice" in \
		2) \
			echo "$(YELLOW)Switching to p3dn.24xlarge...$(NC)"; \
			$(MAKE) start-p3dn; \
			;; \
		*) \
			echo "$(GREEN)Using g5.12xlarge...$(NC)"; \
			$(MAKE) start-g5; \
			;; \
	esac

start-g5: ## Start with g5.12xlarge (4x A10G, 24GB each)
	@echo "$(CYAN)▶️  Starting g5.12xlarge...$(NC)"
	@cd terraform && \
		CURRENT_TYPE=$$(terraform output -raw instance_type 2>/dev/null || echo "none"); \
		if [ "$$CURRENT_TYPE" != "g5.12xlarge" ]; then \
			echo "$(YELLOW)Instance type change detected. Switching instance...$(NC)"; \
			INSTANCE_ID=$$(terraform output -raw instance_id 2>/dev/null); \
			if [ -n "$$INSTANCE_ID" ]; then \
				echo "$(YELLOW)Stopping current instance...$(NC)"; \
				aws ec2 stop-instances --instance-ids $$INSTANCE_ID --region us-east-2 --profile bruno-admin-revalida-aws >/dev/null 2>&1 || true; \
				echo "$(YELLOW)Waiting for instance to stop (max 3 min)...$(NC)"; \
				aws ec2 wait instance-stopped --instance-ids $$INSTANCE_ID --region us-east-2 --profile bruno-admin-revalida-aws 2>/dev/null || true; \
			fi; \
			sed -i.bak 's/instance_type *= *"[^"]*"/instance_type = "g5.12xlarge"/' terraform.tfvars 2>/dev/null || \
			echo 'instance_type = "g5.12xlarge"' >> terraform.tfvars; \
			terraform apply -auto-approve; \
		else \
			INSTANCE_ID=$$(terraform output -raw instance_id 2>/dev/null); \
			aws ec2 start-instances \
				--instance-ids $$INSTANCE_ID \
				--region us-east-2 \
				--profile bruno-admin-revalida-aws; \
			echo "$(YELLOW)Waiting for instance to start...$(NC)"; \
			aws ec2 wait instance-running --instance-ids $$INSTANCE_ID --region us-east-2 --profile bruno-admin-revalida-aws; \
		fi && \
		echo "$(GREEN)✅ g5.12xlarge ready$(NC)"

start-p3dn: ## Start with p3dn.24xlarge (8x V100, 32GB each) - for LongCat
	@echo "$(CYAN)▶️  Starting p3dn.24xlarge...$(NC)"
	@cd terraform && \
		CURRENT_TYPE=$$(terraform output -raw instance_type 2>/dev/null || echo "none"); \
		if [ "$$CURRENT_TYPE" != "p3dn.24xlarge" ]; then \
			echo "$(YELLOW)Instance type change detected. Switching instance...$(NC)"; \
			INSTANCE_ID=$$(terraform output -raw instance_id 2>/dev/null); \
			if [ -n "$$INSTANCE_ID" ]; then \
				echo "$(YELLOW)Stopping current instance...$(NC)"; \
				aws ec2 stop-instances --instance-ids $$INSTANCE_ID --region us-east-2 --profile bruno-admin-revalida-aws >/dev/null 2>&1 || true; \
				echo "$(YELLOW)Waiting for instance to stop (max 3 min)...$(NC)"; \
				aws ec2 wait instance-stopped --instance-ids $$INSTANCE_ID --region us-east-2 --profile bruno-admin-revalida-aws 2>/dev/null || true; \
			fi; \
			sed -i.bak 's/instance_type *= *"[^"]*"/instance_type = "p3dn.24xlarge"/' terraform.tfvars 2>/dev/null || \
			echo 'instance_type = "p3dn.24xlarge"' >> terraform.tfvars; \
			terraform apply -auto-approve; \
		else \
			INSTANCE_ID=$$(terraform output -raw instance_id 2>/dev/null); \
			aws ec2 start-instances \
				--instance-ids $$INSTANCE_ID \
				--region us-east-2 \
				--profile bruno-admin-revalida-aws; \
			echo "$(YELLOW)Waiting for instance to start...$(NC)"; \
			aws ec2 wait instance-running --instance-ids $$INSTANCE_ID --region us-east-2 --profile bruno-admin-revalida-aws; \
		fi && \
		echo "$(GREEN)✅ p3dn.24xlarge ready$(NC)"

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
		COST=$$(terraform output -raw instance_cost_estimate 2>/dev/null) && \
		GPU=$$(terraform output -raw gpu_info 2>/dev/null) && \
		echo "" && \
		echo "  $(GREEN)Instance:$(NC)  $$TYPE" && \
		echo "  $(GREEN)State:$(NC)     $$STATE" && \
		echo "  $(GREEN)IP:$(NC)        $$IP" && \
		echo "  $(GREEN)GPU:$(NC)       $$GPU" && \
		echo "  $(GREEN)Cost:$(NC)      $$COST" && \
		echo "" && \
		if [ "$$TYPE" = "g5.12xlarge" ]; then \
			echo "  $(CYAN)Models:$(NC) Ovi, HunyuanVideo, HoloCine, CogVideoX"; \
		elif [ "$$TYPE" = "p3dn.24xlarge" ]; then \
			echo "  $(CYAN)Models:$(NC) LongCat-Video + all others"; \
		fi

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

setup-hunyuan: ## Setup HunyuanVideo (720p, multi-GPU support)
	@echo "$(CYAN)🎬 Setting up HunyuanVideo...$(NC)"
	@cd ansible && \
		ANSIBLE_HOST_KEY_CHECKING=False \
		ansible-playbook -i inventory.yml playbook.yml --tags setup-hunyuan

test-hunyuan: ## Create HunyuanVideo test script on server
	@echo "$(CYAN)🧪 Setting up HunyuanVideo test...$(NC)"
	@cd ansible && \
		ANSIBLE_HOST_KEY_CHECKING=False \
		ansible-playbook -i inventory.yml playbook.yml --tags test-hunyuan

debug-torch: ## Debug PyTorch installation and versions
	@echo "$(CYAN)🔍 Debugging PyTorch installation...$(NC)"
	@cd ansible && \
		ANSIBLE_HOST_KEY_CHECKING=False \
		ansible-playbook -i inventory.yml playbook.yml --tags debug-torch

setup-cogvideox: ## Setup CogVideoX-5B with xDiT (multi-GPU, HD quality)
	@echo "$(CYAN)🎬 Setting up CogVideoX-5B with xDiT...$(NC)"
	@cd ansible && \
		ANSIBLE_HOST_KEY_CHECKING=False \
		ansible-playbook -i inventory.yml playbook.yml --tags setup-cogvideox

test-cogvideox: ## Create CogVideoX test scripts on server
	@echo "$(CYAN)🧪 Setting up CogVideoX test...$(NC)"
	@cd ansible && \
		ANSIBLE_HOST_KEY_CHECKING=False \
		ansible-playbook -i inventory.yml playbook.yml --tags test-cogvideox

setup-ovi: ## Setup Ovi (video+audio, multi-GPU, FP8 quantization)
	@echo "$(CYAN)🎬 Setting up Ovi (Video+Audio)...$(NC)"
	@cd ansible && \
		ANSIBLE_HOST_KEY_CHECKING=False \
		ansible-playbook -i inventory.yml playbook.yml --tags setup-ovi

test-ovi: ## Create Ovi test scripts on server
	@echo "$(CYAN)🧪 Setting up Ovi test...$(NC)"
	@cd ansible && \
		ANSIBLE_HOST_KEY_CHECKING=False \
		ansible-playbook -i inventory.yml playbook.yml --tags test-ovi

fix-ovi: ## Fix Ovi helper scripts (run if prompts not working)
	@echo "$(CYAN)🔧 Fixing Ovi helper scripts...$(NC)"
	@cd ansible && \
		ANSIBLE_HOST_KEY_CHECKING=False \
		ansible-playbook -i inventory.yml playbook.yml --tags fix-ovi-helper

setup-longcat: ## Setup LongCat-Video (T2V, I2V, Video-Continuation, Long Videos)
	@echo "$(CYAN)🐱 Setting up LongCat-Video...$(NC)"
	@cd ansible && \
		ANSIBLE_HOST_KEY_CHECKING=False \
		ansible-playbook -i inventory.yml playbook.yml --tags setup-longcat

test-longcat: ## Test LongCat-Video installation
	@echo "$(CYAN)🧪 Testing LongCat-Video...$(NC)"
	@cd ansible && \
		ANSIBLE_HOST_KEY_CHECKING=False \
		ansible-playbook -i inventory.yml playbook.yml --tags test-longcat

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
