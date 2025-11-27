# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AWS infrastructure and automation for self-hosted AI video generation using models like HunyuanVideo, HoloCine, CogVideoX, and Ovi. Uses G5.12xlarge instances (4x NVIDIA A10G, 96GB VRAM) with Spot pricing (~$1.70/hour).

## Common Commands

```bash
# Deployment & Management
make deploy              # Complete deployment (Terraform + Ansible)
make start               # Start stopped server
make stop                # Stop server (saves costs!)
make status              # Show server status
make ssh                 # SSH into server

# Model Setup (run after deploy)
make download-models     # Download all 3 main models (~75GB)
make setup-hunyuan       # Setup HunyuanVideo (720p, multi-GPU)
make setup-cogvideox     # Setup CogVideoX-5B with xDiT
make setup-ovi           # Setup Ovi (video+audio generation)

# Video Sync
make sync-videos         # Sync videos to ~/Videos/revalida/
make setup-auto-sync     # Enable automatic sync (every 5 min)

# Terraform
make terraform-plan      # Preview infrastructure changes
make terraform-apply     # Apply Terraform changes only
make validate            # Validate Terraform config
make fmt                 # Format Terraform files

# Debug & Testing
make debug-torch         # Debug PyTorch installation
make test-hunyuan        # Create HunyuanVideo test script
make test-cogvideox      # Create CogVideoX test script
make test-ovi            # Create Ovi test script
```

## Repository Structure

```
revalida-video-generator/
├── Makefile                 # All management commands
├── terraform/               # AWS infrastructure (EC2, EBS, IAM, Security Groups)
├── ansible/
│   ├── deploy.yml          # Orchestrator: Terraform + start instance + configure
│   ├── playbook.yml        # Server setup: packages, volumes, Python env
│   └── tasks/              # Tagged tasks for specific models
│       ├── setup-hunyuan.yml
│       ├── setup-cogvideox.yml
│       ├── setup-ovi.yml
│       └── download-models.yml
├── video_configs/           # JSON configs for HoloCine batch generation
├── generate_parallel.sh     # Multi-GPU parallel video generation
└── docs/
    ├── analise-modelos-text-to-video.md  # Model analysis (Portuguese)
    ├── HOLOCINE.md          # HoloCine usage guide
    ├── HUNYUANVIDEO.md      # HunyuanVideo usage guide
    └── WAN22.md             # Wan 2.2 usage guide
```

## Architecture

### Deployment Flow

1. **Terraform** creates AWS infrastructure (EC2, EBS volumes, IAM, Security Groups, Elastic IP)
2. **Ansible deploy.yml** orchestrates: runs Terraform → starts instance → waits for SSH → runs playbook
3. **Ansible playbook.yml** configures server: mounts EBS, installs packages, creates Python venv

### Server Directories

- `/mnt/models` - AI model weights (500GB EBS volume, persists across stops)
- `/mnt/output` - Generated videos (100GB EBS volume)
- `/home/ubuntu/video-generation/venv` - Python virtual environment

### Ansible Tag System

Model setup tasks use Ansible tags. Each task file has `tags: [tag-name, never]` so it only runs when explicitly requested:

```bash
# How the tags work
make setup-cogvideox  # Runs: ansible-playbook playbook.yml --tags setup-cogvideox
make test-hunyuan     # Runs: ansible-playbook playbook.yml --tags test-hunyuan
```

## Adding a New Model

1. Create `ansible/tasks/setup-<model>.yml` with installation steps
2. Create `ansible/tasks/test-<model>.yml` with test script creation
3. Add import statements to `ansible/playbook.yml`:
   ```yaml
   - name: Include <model> setup tasks
     import_tasks: tasks/setup-<model>.yml
     tags: [setup-<model>, never]
   ```
4. Add Makefile targets:
   ```makefile
   setup-<model>: ## Setup <model> description
   	@cd ansible && ansible-playbook -i inventory.yml playbook.yml --tags setup-<model>
   ```
5. Add usage guide at `docs/<MODEL>.md`

## Server Commands (via SSH)

After `make ssh`, these aliases are available:
- `video-status` - System overview (GPU, disk, memory)
- `venv` - Activate Python venv
- `download-model <name>` - Download from HuggingFace (e.g., `download-model tencent/HunyuanVideo`)
- `gpuwatch` - Monitor GPU usage
- `cdmodels` / `cdoutput` - Navigate to directories

## Video Generation Workflow

### HoloCine Multi-Shot (via JSON configs)

```bash
# 1. Create config in video_configs/
cp video_configs/template.json video_configs/my_video.json

# 2. Copy to server
scp video_configs/*.json ubuntu@<IP>:/mnt/output/

# 3. Generate (on server)
python3 /mnt/output/run_holocine.py /mnt/output/my_video.json

# Or parallel generation using all 4 GPUs:
bash /mnt/output/generate_parallel.sh config1.json config2.json config3.json config4.json
```

### CogVideoX with xDiT (multi-GPU)

```bash
# Single GPU
python3 test_cogvideox_single.py

# Multi-GPU (4 GPUs, 3.91x speedup)
torchrun --nproc_per_node=4 xDiT/examples/cogvideox_example.py --model /mnt/models/CogVideoX-5b
```

## Key Technical Details

- **Deep Learning AMI**: Ubuntu base with NVIDIA drivers pre-installed. LVM on nvme1n1 is automatically removed by Ansible to use as models volume.
- **Spot Instances**: Configured with `instance_interruption_behavior = "stop"` (not terminate) to preserve data.
- **EBS Volumes**: Persist across instance stops. Only destroyed with `make destroy`.

## Document Language

The analysis document (`docs/analise-modelos-text-to-video.md`) is in **Brazilian Portuguese**. Maintain this language when updating.
