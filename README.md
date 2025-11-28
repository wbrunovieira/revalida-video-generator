# Revalida Video Generator

AWS-based infrastructure for self-hosted AI video generation using models like CogVideoX and Ovi.

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

| Instance      | Spot     | On-Demand | Best For                  |
| ------------- | -------- | --------- | ------------------------- |
| g5.12xlarge   | ~$1.70/h | ~$5.67/h  | Ovi, CogVideoX , Wan      |
| p3dn.24xlarge | ~$10/h   | ~$31/h    | Large models (32GB+ VRAM) |

- **Stopped:** $0/hour (both instances)
- **Storage:** ~$56/month (EBS volumes persist between switches)
- **vs Sora:** 93-98% cheaper per video

**💡 Tips:**

- Use `make stop` when not generating videos
- Use g5 (default) for most work, p3dn for large models
- EBS volumes shared between instances - no re-download needed

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
- `make start` - Start server (interactive instance selection)
- `make start-g5` - Start with g5.12xlarge (4x A10G, 24GB each) - ~$1.70/h
- `make start-p3dn` - Start with p3dn.24xlarge (8x V100, 32GB each) - ~$10/h
- `make stop` - Stop server (saves costs!)
- `make status` - Show server status (instance type, GPU, cost)
- `make ssh` - SSH into server

### Hybrid Instance Setup

Switch between instance types based on your needs:

| Instance      | GPUs    | VRAM/GPU | Cost (Spot) | Best For                  |
| ------------- | ------- | -------- | ----------- | ------------------------- |
| g5.12xlarge   | 4x A10G | 24GB     | ~$1.70/h    | Ovi, CogVideoX            |
| p3dn.24xlarge | 8x V100 | 32GB     | ~$10/h      | Large models (32GB+ VRAM) |

```bash
# Interactive selection
make start

# Or directly
make start-g5      # Standard usage
make start-p3dn    # For large models (32GB+ VRAM)
```

**Note:** EBS volumes (models + outputs) persist between instance switches.

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

- **Wan 2.2** (~20GB) - Most versatile (T2V + I2V)
- **Ovi** (~70GB) - Video + synchronized audio generation

**Option 2: Download specific model**

```bash
# From your local machine
make download-model MODEL=THUDM/CogVideoX-5b

# or SSH into server
ssh ubuntu@<IP>
download-model THUDM/CogVideoX-5b
download-model feizhengcong/Ovi
```

### Generate Videos

**Quick start guides for each model:**

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

# Or use CogVideoX
cd /mnt/models/CogVideoX
python test_cogvideox.py
```

### Ovi (Video + Audio)

Ovi generates **video with synchronized audio** in a single pass - perfect for videos with speech, music, or sound
effects. Supports both **Text-to-Video (T2V)** and **Image-to-Video (I2V)** modes.

**Setup Ovi:**

```bash
# From local machine
make setup-ovi

# If having issues, run fix
make fix-ovi
```

**Available scripts:** | Script | Mode | Resolution | Duration | |--------|------|------------|----------| |
`ovi_generate.sh` | T2V | 720×720 | 5 seconds | | `ovi_i2v.sh` | I2V | 720×720 | 5 seconds | | `ovi_i2v_10s.sh` | I2V |
960×960 | 10 seconds |

#### Text-to-Video (T2V) - Generate from prompt only

```bash
make ssh
venv

# Basic usage
~/video-generation/ovi_generate.sh "Doctor in white coat speaking. Audio: Professional voice with hospital ambiance"
```

#### Image-to-Video (I2V) - Animate your character image

Use I2V when you want **character consistency** - the person in your image will be animated speaking!

```bash
make ssh
venv

# 1. Upload your character image to server (from local machine)
scp ~/my_doctor.png ubuntu@<IP>:/mnt/output/

# 2. Generate video with your character speaking (5 seconds)
~/video-generation/ovi_i2v.sh /mnt/output/my_doctor.png \
  "Doctor speaking to camera. Audio: <S>Buongiorno, sono il Dottor Rossi. Oggi parleremo di cardiologia.<E> Soft office ambiance"

# 3. Or generate 10-second video (higher quality 960x960)
~/video-generation/ovi_i2v_10s.sh /mnt/output/my_doctor.png \
  "Doctor explaining procedure. Audio: <S>La pressione sanguigna normale è tra 120 e 80.<E> Hospital background"
```

#### Prompt format for speech

Use `<S>...<E>` tags to make characters speak:

```bash
# Character speaking Italian
"Doctor in hospital. Audio: <S>Buongiorno, benvenuti al corso di italiano medico.<E> Soft background music"

# Multiple sentences
"Person presenting. Audio: <S>Welcome to our presentation. Today we will discuss important topics.<E> Office ambiance"

# No speech, just sounds
"Ocean sunset scene. Audio: Calm piano melody with gentle wave sounds"
```

#### Best practices for I2V (tested and verified)

Based on extensive testing, these tips will help you get the best results:

**1. Use natural, descriptive prompts (NOT technical)**

```bash
# GOOD - Natural description
"A friendly Italian doctor in white coat warmly greeting the camera and speaking.
He is animated and expressive, gesturing naturally as he talks. Professional medical setting."

# BAD - Too technical (may cause static image)
"Doctor with lip movements and mouth opening closing synchronized to speech."
```

**2. Keep speech short for 5-second videos**

```bash
# GOOD - Short phrase fits well in 5 seconds
"Audio: <S>Ciao! Benvenuto al corso Revalida Italia.<E> Gentle piano music"

# BAD - Too long, audio will be rushed/cut
"Audio: <S>Benvenuto al Corso di Italiano Medico della Revalida Italia. Oggi parleremo di...<E>"
```

**3. Use custom config for fine-tuning**

For best results, create a custom YAML config:

```bash
# SSH into server
make ssh
venv

# Create custom config
cat > /tmp/custom_i2v.yaml << 'EOF'
model_name: "720x720_5s"
output_dir: "/mnt/output"
ckpt_dir: "/mnt/models/Ovi"

sample_steps: 50
solver_name: "unipc"
shift: 5.0
seed: 12345                    # Try different seeds for variation

audio_guidance_scale: 3.0
video_guidance_scale: 5.0      # Higher = more prompt adherence (default 4.0)
slg_layer: 11

sp_size: 1
cpu_offload: True
fp8: True

mode: "i2v"
image_path: "/mnt/output/your_image.png"
text_prompt: "A friendly doctor speaking warmly to camera. Audio: <S>Your speech here.<E> Background music."
video_frame_height_width: [720, 720]
each_example_n_times: 1

video_negative_prompt: "static, frozen, still image, no movement, blur, distortion"
audio_negative_prompt: "robotic, fast, unclear, distorted, muffled"
EOF

# Run with custom config
cd /mnt/models/Ovi-code
python3 inference.py --config-file /tmp/custom_i2v.yaml
```

**4. Key parameters to experiment with:**

| Parameter               | Default | Effect                                   |
| ----------------------- | ------- | ---------------------------------------- |
| `seed`                  | 42      | Different seeds = different results      |
| `video_guidance_scale`  | 4.0     | Higher (5.0-6.0) = more prompt adherence |
| `sample_steps`          | 50      | More steps = better quality (slower)     |
| `video_negative_prompt` | -       | Avoid unwanted artifacts                 |

**5. Important limitations:**

- **FP8 only works with 720x720_5s** - The 10-second 960x960 model requires full precision (more VRAM)
- **5 seconds is the limit** with FP8 quantization on 24GB VRAM
- **Lip sync is approximate** - Ovi generates audio and video together but sync isn't perfect

#### Workflow for consistent character videos

1. **Create/obtain a reference image** of your character (doctor, presenter, etc.)
2. **Upload to server:** `scp character.png ubuntu@<IP>:/mnt/output/`
3. **Generate multiple videos** using the same image with different prompts:

```bash
# Video 1: Introduction
~/video-generation/ovi_i2v.sh /mnt/output/doctor.png \
  "Doctor smiling at camera. Audio: <S>Ciao! Mi chiamo Dottor Rossi.<E> Warm office sounds"

# Video 2: Lesson content
~/video-generation/ovi_i2v.sh /mnt/output/doctor.png \
  "Doctor explaining with gestures. Audio: <S>Oggi impariamo i termini medici.<E> Calm background"

# Video 3: Conclusion
~/video-generation/ovi_i2v.sh /mnt/output/doctor.png \
  "Doctor waving goodbye. Audio: <S>Grazie per aver seguito la lezione. Arrivederci!<E> Soft music"
```

The **same doctor** will appear in all videos, maintaining consistency!

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
└── docs/                 # Documentation
```

## 🔐 Security

- `terraform.tfstate` - Gitignored (contains IPs, IDs)
- `terraform.tfvars` - Gitignored (contains AWS profile)
- `ansible/inventory.yml` - Gitignored (auto-generated)
- SSH keys stored in `~/.ssh/` (not in repo)

## 🎯 Recommended Models

Recommended models for this project:

**Best for Video + Audio + Character Consistency:**

- Ovi (720×720 or 960×960, 5-10s)
- Generates synchronized audio with video in single pass
- **I2V mode:** Use your character image for consistent talking head videos
- Perfect for speech, narration, music, sound effects

**Most Versatile:**

- Wan 2.2 (supports both text-to-video and image-to-video)

**Best Quality/Performance Balance:**

- CogVideoX-5B (720p, multi-GPU support with xDiT)

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

**Created with:** Terraform + Ansible + Make **GPU:** NVIDIA A10G (4x on G5.12xlarge) **Models:** CogVideoX, Ovi
