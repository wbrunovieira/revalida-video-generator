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
	@echo "     $(CYAN)Best for: Ovi, CogVideoX, Wan 2.2$(NC)"
	@echo ""
	@echo "  $(GREEN)2)$(NC) p3dn.24xlarge - 8x V100 (32GB each) - ~$$10/h spot"
	@echo "     $(CYAN)Best for: Large models requiring 32GB+ VRAM/GPU$(NC)"
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

start-p3dn: ## Start with p3dn.24xlarge (8x V100, 32GB each)
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
			echo "  $(CYAN)Models:$(NC) Ovi, CogVideoX, Wan 2.2"; \
		elif [ "$$TYPE" = "p3dn.24xlarge" ]; then \
			echo "  $(CYAN)Models:$(NC) Large models requiring 32GB+ VRAM/GPU"; \
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

download-models: ## Download Wan 2.2 model (~20GB)
	@echo "$(CYAN)📥 Downloading main AI models...$(NC)"
	@echo "$(YELLOW)⚠️  This will download ~20GB and take 15-30 minutes$(NC)"
	@cd ansible && \
		ANSIBLE_HOST_KEY_CHECKING=False \
		ansible-playbook -i inventory.yml playbook.yml --tags download-models

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

setup-wan14b: ## Setup WAN 14B Rapid (ultra-fast 4 steps, ComfyUI)
	@echo "$(CYAN)🎬 Setting up WAN 14B Rapid AllInOne...$(NC)"
	@cd ansible && \
		ANSIBLE_HOST_KEY_CHECKING=False \
		ansible-playbook -i inventory.yml playbook.yml --tags setup-wan14b

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
	@mkdir -p ~/Videos/revalida ~/Videos/revalida/comfyui
	@cd terraform && \
		IP=$$(terraform output -raw public_ip 2>/dev/null) && \
		rsync -avz --progress --ignore-existing -e "ssh -i ~/.ssh/id_rsa" \
			ubuntu@$$IP:/mnt/output/ ~/Videos/revalida/ && \
		rsync -avz --progress --ignore-existing -e "ssh -i ~/.ssh/id_rsa" \
			ubuntu@$$IP:/mnt/models/ComfyUI/output/ ~/Videos/revalida/comfyui/ 2>/dev/null || true && \
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

# =============================================================================
# Video Generation Commands
# =============================================================================

generate: ## Generate video (interactive mode)
	@echo "$(CYAN)🎬 Video Generation$(NC)"
	@echo ""
	@echo "$(YELLOW)Select model:$(NC)"
	@echo "  1) ovi      - Video + Audio sync (recommended)"
	@echo "  2) cogvideox - High quality, multi-GPU"
	@echo "  3) wan      - Versatile T2V/I2V"
	@echo ""
	@read -p "Model [1-3]: " model_choice; \
	case "$$model_choice" in \
		1) MODEL="ovi" ;; \
		2) MODEL="cogvideox" ;; \
		3) MODEL="wan" ;; \
		*) MODEL="ovi" ;; \
	esac; \
	echo ""; \
	echo "$(YELLOW)Select mode:$(NC)"; \
	echo "  1) t2v - Text to Video"; \
	echo "  2) i2v - Image to Video"; \
	echo ""; \
	read -p "Mode [1-2]: " mode_choice; \
	case "$$mode_choice" in \
		2) MODE="i2v" ;; \
		*) MODE="t2v" ;; \
	esac; \
	echo ""; \
	read -p "Prompt: " PROMPT; \
	if [ "$$MODE" = "i2v" ]; then \
		read -p "Image path: " IMAGE; \
	fi; \
	$(MAKE) run-generate MODEL=$$MODEL MODE=$$MODE PROMPT="$$PROMPT" IMAGE="$$IMAGE"

run-generate: ## Run video generation (usage: make run-generate MODEL=ovi MODE=t2v PROMPT="...")
	@cd terraform && \
		IP=$$(terraform output -raw public_ip 2>/dev/null) && \
		ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@$$IP \
			"generate-video $(MODEL) $(MODE) '$(PROMPT)' $(IMAGE)"

deploy-scripts: ## Deploy video generation scripts to server
	@echo "$(CYAN)📤 Deploying scripts to server...$(NC)"
	@cd terraform && \
		IP=$$(terraform output -raw public_ip 2>/dev/null) && \
		scp -i ~/.ssh/id_rsa ../ansible/files/generate-video.sh ubuntu@$$IP:~/video-generation/ && \
		ssh -i ~/.ssh/id_rsa ubuntu@$$IP "chmod +x ~/video-generation/generate-video.sh && sudo ln -sf ~/video-generation/generate-video.sh /usr/local/bin/generate-video"
	@echo "$(GREEN)✅ Scripts deployed$(NC)"

# Git helpers
commit: ## Git commit with standardized message
	@git add .
	@git status
	@echo "$(CYAN)Enter commit message:$(NC)"
	@read msg; git commit -m "$$msg"

push: commit ## Commit and push to GitHub
	@git push origin main
