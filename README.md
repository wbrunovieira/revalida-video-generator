# Revalida Video Generator

AWS-based infrastructure for self-hosted AI video generation using models like HunyuanVideo, HoloCine, and CogVideoX.

## 🚀 Quick Start

```bash
# Complete deployment (first time)
make deploy

# Start server (if stopped)
make start

# SSH into server
make ssh

# Stop server to save costs
make stop
```

## 📋 What This Does

This project provides **complete automation** for deploying and managing a GPU server for AI video generation:

1. **Terraform** manages AWS infrastructure:
   - GPU instance (G5.12xlarge with 4x NVIDIA A10G)
   - EBS volumes for models and output
   - Security groups, IAM roles, Elastic IP

2. **Ansible** configures the server:
   - Mounts EBS volumes
   - Installs Python, PyTorch, Diffusers
   - Downloads AI models
   - Creates helper scripts and aliases

3. **Makefile** provides simple commands:
   - `make deploy` - Full deployment
   - `make start/stop` - Manage server state
   - `make ssh` - Connect to server

## 💰 Cost Optimization

- **Running:** ~$1.70/hour (Spot) or ~$5.67/hour (On-Demand)
- **Stopped:** $0/hour
- **Storage:** ~$56/month (EBS volumes persist)
- **vs Sora:** 93-98% cheaper per video

**💡 Tip:** Use `make stop` when not generating videos!

## 📦 Prerequisites

- AWS account with CLI configured
- Terraform installed
- Ansible installed
- SSH key pair (`~/.ssh/id_rsa`)
- AWS quota for GPU instances (see below)

## 🔧 Setup

### 1. Configure AWS Credentials

```bash
aws configure --profile bruno-admin-revalida-aws
```

### 2. Request GPU Quota

⚠️ **Required:** Request AWS quota increase for GPU instances:

- Go to AWS Service Quotas
- Service: EC2
- Quota: "Running On-Demand G and VT instances"
- Request: 96 vCPUs (for G5.12xlarge)
- Wait: 24-48 hours for approval

### 3. Configure Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your AWS profile
```

### 4. Deploy!

```bash
make deploy
```

This will:
1. Create AWS infrastructure
2. Start the server
3. Mount EBS volumes
4. Install all software
5. Configure Python environment

Takes ~15-20 minutes on first run.

## 📚 Available Commands

### Deployment & Management
- `make deploy` - Complete deployment (Terraform + Ansible)
- `make start` - Start stopped server
- `make stop` - Stop server (saves costs!)
- `make status` - Show server status
- `make ssh` - SSH into server

### Infrastructure
- `make terraform-plan` - Preview infrastructure changes
- `make terraform-apply` - Apply Terraform changes
- `make ansible-only` - Run Ansible config only
- `make destroy` - Destroy all infrastructure ⚠️

### Server Operations
- `make video-status` - Show detailed server status
- `make download-model MODEL=<name>` - Download AI model
- `make logs` - View deployment logs

### Development
- `make validate` - Validate Terraform config
- `make fmt` - Format Terraform files
- `make clean` - Clean temp files

## 🎮 Using the Server

### Connect
```bash
make ssh
# or
ssh -i ~/.ssh/id_rsa ubuntu@<IP>
```

### Available Commands on Server
```bash
video-status          # System overview
venv                  # Activate Python
download-model <name> # Download AI model
gpuwatch              # Monitor GPU
cdmodels              # Go to /mnt/models
cdoutput              # Go to /mnt/output
```

### Download AI Models
```bash
# From your local machine
make download-model MODEL=tencent/HunyuanVideo

# or SSH into server
ssh ubuntu@<IP>
download-model tencent/HunyuanVideo
download-model yihao-meng/HoloCine
download-model THUDM/CogVideoX-5b
```

### Generate Videos
```bash
# SSH into server
make ssh

# Activate Python
venv

# Your generation code here
python generate_video.py
```

### Copy Videos to Local
```bash
scp -i ~/.ssh/id_rsa ubuntu@<IP>:/mnt/output/*.mp4 ~/Downloads/
```

## 📁 Project Structure

```
revalida-video-generator/
├── Makefile              # Management commands
├── README.md             # This file
├── .gitignore            # Protects secrets
├── terraform/            # AWS infrastructure
│   ├── *.tf             # Terraform configs
│   └── terraform.tfvars # Your settings (gitignored)
├── ansible/              # Server configuration
│   ├── deploy.yml       # Orchestrator playbook
│   ├── playbook.yml     # Server setup
│   └── tasks/           # Reusable tasks
└── docs/
    └── analise-modelos-text-to-video.md  # Model analysis
```

## 🔐 Security

- `terraform.tfstate` - Gitignored (contains IPs, IDs)
- `terraform.tfvars` - Gitignored (contains AWS profile)
- `ansible/inventory.yml` - Gitignored (auto-generated)
- SSH keys stored in `~/.ssh/` (not in repo)

## 🎯 Recommended Models

Based on analysis in `docs/analise-modelos-text-to-video.md`:

**Best Overall Quality:**
- HunyuanVideo (1280×720, 30 FPS, 5s)
- With LoRA training for character consistency

**Best for Long Videos:**
- HoloCine-14B (720×480, 16 FPS, up to 60s)
- Native multi-shot support

**Most Versatile:**
- Wan 2.2 (supports both text-to-video and image-to-video)

## 💡 Tips

### Daily Workflow
```bash
# Morning
make start
make ssh

# Work with models

# Evening
make stop    # Save money!
```

### Monitor Costs
```bash
# Check instance state
make status

# Estimate costs
# Running: $1.70/hour × hours
# Storage: $56/month (fixed)
```

### Troubleshooting
```bash
# Can't SSH?
make status  # Check if running

# Terraform errors?
make terraform-plan

# Ansible errors?
make ansible-only

# Start fresh?
make destroy && make deploy
```

## 📖 Documentation

- `terraform/README.md` - Infrastructure details
- `ansible/README.md` - Configuration details
- `docs/analise-modelos-text-to-video.md` - Model comparison (Portuguese)
- `CLAUDE.md` - For Claude Code AI assistant

## 🤝 Contributing

This is a personal project, but PRs welcome!

## 📄 License

MIT

## 🙋 Support

- Check `terraform/README.md` for infrastructure issues
- Check `ansible/README.md` for configuration issues
- AWS quota problems: See AWS Service Quotas console

---

**Created with:** Terraform + Ansible + Make
**GPU:** NVIDIA A10G (4x on G5.12xlarge)
**Models:** HunyuanVideo, HoloCine, CogVideoX, and more
