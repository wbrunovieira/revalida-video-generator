# Revalida Video Generator

AWS-based infrastructure for self-hosted AI video generation using models like HunyuanVideo, HoloCine, CogVideoX, and Ovi.

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
- `make download-models` - Download all 3 main models (~75GB, 30-60 min)
- `make download-model MODEL=<name>` - Download specific AI model
- `make logs` - View deployment logs

### Video Sync
- `make sync-videos` - Sync videos from server to ~/Videos/revalida/
- `make setup-auto-sync` - Enable automatic sync (every 5 min)
- `make remove-auto-sync` - Disable automatic sync

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

**Option 1: Download all 3 main models automatically**
```bash
# From your local machine (recommended)
make download-models
```

This downloads:
- **HoloCine** (~30GB) - Multi-shot with character consistency
- **HunyuanVideo** (~25GB) - Best quality, supports LoRA
- **Wan 2.2** (~20GB) - Most versatile (T2V + I2V)
- **Ovi** (~70GB) - Video + synchronized audio generation

**Option 2: Download specific model**
```bash
# From your local machine
make download-model MODEL=tencent/HunyuanVideo

# or SSH into server
ssh ubuntu@<IP>
download-model tencent/HunyuanVideo
download-model yihao-meng/HoloCine
download-model THUDM/CogVideoX-5b
download-model feizhengcong/Ovi
```

### Generate Videos

**Quick start guides for each model:**
- 📖 **[HoloCine](docs/HOLOCINE.md)** - Multi-shot narrative videos
- 📖 **[HunyuanVideo](docs/HUNYUANVIDEO.md)** - Highest quality, LoRA support
- 📖 **[Wan 2.2](docs/WAN22.md)** - Text-to-Video & Image-to-Video
- 📖 **[Ovi](#ovi-video--audio)** - Video with synchronized audio

**Example workflow:**
```bash
# SSH into server
make ssh

# Activate Python
venv

# Generate with HunyuanVideo
cd /mnt/output
python generate_hunyuan.py

# Or use HoloCine for multi-shot
cd /mnt/models/HoloCine/code
python HoloCine_inference_full_attention.py
```

### Ovi (Video + Audio)

Ovi generates **video with synchronized audio** in a single pass - perfect for videos with speech, music, or sound effects.

**Setup Ovi:**
```bash
# From local machine
make setup-ovi
```

**Generate video+audio:**
```bash
# SSH into server
make ssh
venv

# Use the helper script
~/video-generation/ovi_generate.sh "A person speaking in a modern office. Audio: Professional male voice saying 'Welcome to our presentation' with soft background music"
```

**Prompt format:**
- Describe the video scene first
- Add `Audio:` followed by audio description
- For 720x720 model, audio uses `<AUDCAP>...</ENDAUDCAP>` tags (auto-converted)
- For 960x960 model, use `Audio: ...` format directly

**Available models:**
| Model | Resolution | Duration | Use Case |
|-------|------------|----------|----------|
| `720x720_5s` | 720×720 | 5 seconds | Default, FP8 quantization available |
| `960x960_5s` | 960×960 | 5 seconds | Higher quality |
| `960x960_10s` | 960×960 | 10 seconds | Longer videos |

**Example prompts:**
```bash
# Doctor speaking
~/video-generation/ovi_generate.sh "Medium shot of doctor in white coat, hospital background. Audio: Warm male voice saying 'Hello, I am Doctor Smith' with ambient hospital sounds"

# Nature scene with music
~/video-generation/ovi_generate.sh "Beautiful sunset over ocean waves. Audio: Calm piano melody with gentle wave sounds"
```

### Copy Videos to Local

**Option 1: Manual sync (on-demand)**
```bash
make sync-videos
```

**Option 2: Automatic sync (every 5 minutes)**
```bash
# Enable auto-sync
make setup-auto-sync

# Disable auto-sync
make remove-auto-sync

# Check sync logs
tail -f /tmp/revalida-sync.log
```

**Videos location:** `~/Videos/revalida/`

**How it works:**
- Uses `rsync` with `--ignore-existing` (doesn't re-download)
- Preserves file timestamps and permissions
- Shows progress during transfer
- Only downloads new videos (efficient)

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

**Best for Video + Audio:**
- Ovi (720×720 or 960×960, 5-10s)
- Generates synchronized audio with video in single pass
- Perfect for speech, narration, music, sound effects

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
**Models:** HunyuanVideo, HoloCine, CogVideoX, Ovi
