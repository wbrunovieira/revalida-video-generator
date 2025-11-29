# terraform/instance.tf

# Create or import SSH key pair
resource "aws_key_pair" "video_generation" {
  key_name   = var.key_name
  public_key = file(pathexpand(var.public_key_path))

  tags = {
    Name    = var.key_name
    Project = var.project_name
  }
}

# GPU instance for video generation
resource "aws_instance" "video_generation" {
  ami                    = var.ami_id != "" ? var.ami_id : data.aws_ami.deep_learning_ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.video_generation.key_name
  iam_instance_profile   = aws_iam_instance_profile.video_generation_profile.name
  vpc_security_group_ids = [aws_security_group.video_generation_sg.id]
  availability_zone      = data.aws_availability_zones.available.names[0]

  # Use Spot instance if enabled
  instance_market_options {
    market_type = var.use_spot_instance ? "spot" : null

    dynamic "spot_options" {
      for_each = var.use_spot_instance ? [1] : []
      content {
        max_price                      = var.spot_max_price != "" ? var.spot_max_price : null
        spot_instance_type             = "persistent"
        instance_interruption_behavior = "stop"
      }
    }
  }

  # Root volume configuration
  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    iops                  = 3000
    throughput            = 125
    delete_on_termination = true
    encrypted             = true

    tags = {
      Name    = "${var.project_name}-root-volume"
      Project = var.project_name
    }
  }

  # User data script - basic setup
  user_data = <<-EOF
    #!/bin/bash
    set -e

    # Update system
    apt-get update -y

    # Install essential tools
    apt-get install -y \
      build-essential \
      git \
      wget \
      curl \
      vim \
      htop \
      nvtop \
      tmux \
      python3-pip \
      python3-venv \
      awscli \
      jq \
      rsync

    # Create directories for models and output
    mkdir -p /mnt/models
    mkdir -p /mnt/output
    mkdir -p /home/ubuntu/video-generation
    chown -R ubuntu:ubuntu /home/ubuntu/video-generation

    # Install NVIDIA container toolkit (for optional Docker use later)
    distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
      sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
      tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
    apt-get update
    apt-get install -y nvidia-container-toolkit

    # Verify NVIDIA drivers
    nvidia-smi > /home/ubuntu/gpu-info.txt

    # Create Python virtual environment
    sudo -u ubuntu python3 -m venv /home/ubuntu/video-generation/venv

    # Install common ML packages
    sudo -u ubuntu /home/ubuntu/video-generation/venv/bin/pip install --upgrade pip
    sudo -u ubuntu /home/ubuntu/video-generation/venv/bin/pip install \
      torch \
      torchvision \
      torchaudio \
      diffusers \
      transformers \
      accelerate \
      xformers \
      huggingface-hub \
      opencv-python \
      Pillow \
      numpy \
      scipy \
      jupyter \
      ipykernel

    # Setup Jupyter
    sudo -u ubuntu /home/ubuntu/video-generation/venv/bin/python -m ipykernel install --user --name=video-gen

    # Create welcome script
    cat > /home/ubuntu/welcome.sh << 'WELCOME'
    #!/bin/bash
    echo "================================"
    echo "Video Generation Server Ready!"
    echo "================================"
    echo ""
    echo "GPU Info:"
    nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv
    echo ""
    echo "Directories:"
    echo "  Models:  /mnt/models"
    echo "  Output:  /mnt/output"
    echo "  Project: /home/ubuntu/video-generation"
    echo ""
    echo "Python Environment:"
    echo "  Activate: source /home/ubuntu/video-generation/venv/bin/activate"
    echo ""
    echo "Next steps:"
    echo "  1. Mount EBS volumes (if not auto-mounted)"
    echo "  2. Download AI models to /mnt/models"
    echo "  3. Start generating videos!"
    echo "  4. Copy videos to local: scp ubuntu@IP:/mnt/output/*.mp4 ."
    echo ""
    WELCOME
    chmod +x /home/ubuntu/welcome.sh

    # Add to .bashrc
    echo "/home/ubuntu/welcome.sh" >> /home/ubuntu/.bashrc

    # Signal completion
    touch /home/ubuntu/setup-complete.txt
  EOF

  tags = {
    Name    = "${var.project_name}-server"
    Project = var.project_name
    Type    = "GPU-Compute"
  }

  # Prevent accidental termination
  disable_api_termination = false

  lifecycle {
    ignore_changes = [
      ami,
      user_data
    ]
  }
}

# Attach models volume
resource "aws_volume_attachment" "models" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.models.id
  instance_id = aws_instance.video_generation.id

  # Don't force detach on destroy
  force_detach = false
}

# REMOVED: aws_volume_attachment.output
# Videos now stored on ephemeral Instance Store (3.5TB)
# and synced to local via SSH (make sync-videos)

# Elastic IP for persistent IP address
resource "aws_eip" "video_generation" {
  instance = aws_instance.video_generation.id
  domain   = "vpc"

  tags = {
    Name    = "${var.project_name}-eip"
    Project = var.project_name
  }

  depends_on = [aws_instance.video_generation]
}
