# Ansible Configuration for Video Generation Server

This directory contains Ansible playbooks to configure the GPU server for video generation.

## Files

- **playbook.yml** - Main setup playbook (runs automatically via Terraform)
- **inventory.tpl** - Template for Ansible inventory (populated by Terraform)
- **inventory.yml** - Generated inventory (gitignored, created by Terraform)
- **files/bashrc-additions.sh** - Bash aliases and helper functions

## What the Playbook Does

### 1. System Setup
- Updates packages
- Installs essential tools (git, curl, htop, nvtop, ffmpeg, etc)

### 2. EBS Volume Configuration
- Formats volumes (if needed)
- Mounts `/mnt/models` (for AI models)
- Mounts `/mnt/output` (for generated videos)
- Adds to `/etc/fstab` for automatic mounting on boot

### 3. GPU Verification
- Detects if GPU is present
- Displays GPU information via `nvidia-smi`
- Shows warning if CPU-only instance

### 4. Python Environment
- Creates virtual environment at `/home/ubuntu/video-generation/venv`
- Installs ML packages:
  - PyTorch, Diffusers, Transformers
  - HuggingFace Hub, xformers
  - OpenCV, Pillow, Numpy, Scipy
  - Jupyter for experimentation

### 5. Helper Scripts & Aliases
Creates useful commands:
- `video-status` - Complete system overview
- `download-model <name>` - Download AI models
- `venv` - Activate Python environment
- `gpuwatch` - Monitor GPU usage
- `cdmodels`, `cdoutput` - Navigate quickly
- `sysinfo` - Quick system info

## Automatic Execution

The playbook runs **automatically** when you do `terraform apply`:

```bash
terraform apply
# 1. Creates infrastructure
# 2. Generates inventory.yml
# 3. Waits for SSH
# 4. Runs ansible playbook
# 5. Server is fully configured!
```

## Manual Execution

If you need to run Ansible manually:

```bash
cd ansible

# Run the main playbook
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventory.yml playbook.yml

# Run with verbosity
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventory.yml playbook.yml -vv
```

## After Setup

SSH into the server:
```bash
ssh -i ~/.ssh/id_rsa ubuntu@<SERVER_IP>
```

You'll see a welcome message with available commands!

### Quick Commands

```bash
# Check system status
video-status

# Activate Python environment
venv

# Download a model
download-model tencent/HunyuanVideo

# Monitor GPU
gpuwatch

# Check disk space
diskspace

# See all aliases
alias | grep -E "models|output|venv|gpu"
```

## Troubleshooting

### SSH Connection Refused
Wait a few minutes - instance is still booting.

### Ansible Connection Failed
Check if SSH works manually first:
```bash
ssh -i ~/.ssh/id_rsa ubuntu@<SERVER_IP>
```

### Volumes Not Mounted
SSH into server and check:
```bash
lsblk  # List block devices
df -h  # Show mounted filesystems
```

Re-run mount commands if needed:
```bash
sudo mount /dev/nvme1n1 /mnt/models
sudo mount /dev/nvme2n1 /mnt/output
```

### Python Packages Install Failed
Check if still installing:
```bash
ps aux | grep pip
```

Install manually if needed:
```bash
source /home/ubuntu/video-generation/venv/bin/activate
pip install torch diffusers transformers
```

## Directory Structure

```
/home/ubuntu/video-generation/    # Application directory
├── venv/                          # Python virtual environment
└── ...

/mnt/models/                       # AI models (500GB EBS)
├── Ovi/
├── Wan2.2/
└── CogVideoX-5b/

/mnt/output/                       # Generated videos (200GB EBS)
├── video_001.mp4
├── video_002.mp4
└── ...
```

## Next Steps After Setup

1. **Download AI Models**
   ```bash
   download-model tencent/HunyuanVideo
   ```

2. **Test GPU** (if present)
   ```bash
   nvidia-smi
   python -c "import torch; print(torch.cuda.is_available())"
   ```

3. **Start Generating Videos!**

## Notes

- The playbook is **idempotent** - safe to run multiple times
- EBS volumes are formatted only if not already formatted
- Python packages install runs in background (may take 10-20 min)
- All setup logs are visible during `terraform apply`
