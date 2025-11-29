#!/bin/bash
# mount-ebs.sh - Mount EBS volume after server restart
# Called by: make start -> mount-volumes
#
# Architecture (simplified):
# - 1x 500GB EBS -> /mnt/models (AI models - persistent)
# - Instance Store 3.5TB -> /mnt/output (videos - ephemeral, sync to local)

echo "🔍 Detecting storage volumes..."

# Find the 500GB EBS volume (not root, not instance store)
# EBS volumes are typically nvme1n1 or nvme2n1, around 500GB
MODELS_VOL=$(lsblk -d -n -o NAME,SIZE | grep -E '500G|450G|400G' | grep -v nvme0 | head -1 | awk '{print $1}')

if [ -z "$MODELS_VOL" ]; then
    echo "⚠️  No 500GB EBS volume found, trying alternative detection..."
    # Try to find any EBS volume that's not root and not huge (instance store)
    MODELS_VOL=$(lsblk -d -n -o NAME,SIZE | grep -E 'nvme[1-3]n1' | grep -vE '[0-9]T' | head -1 | awk '{print $1}')
fi

if [ -z "$MODELS_VOL" ]; then
    echo "❌ No EBS volume found for models"
    echo "Available volumes:"
    lsblk -d -o NAME,SIZE,TYPE
    exit 1
fi

echo "📦 Found models volume: /dev/$MODELS_VOL"

# Remove symlink if exists (from old config)
if [ -L "/mnt/models" ]; then
    sudo rm -f /mnt/models
fi

# Mount EBS directly to /mnt/models
sudo mkdir -p /mnt/models 2>/dev/null || true
if ! mountpoint -q /mnt/models; then
    echo "  Mounting /dev/$MODELS_VOL -> /mnt/models"
    sudo mount /dev/$MODELS_VOL /mnt/models 2>/dev/null || {
        echo "  ⚠️  Mount failed, checking if volume needs formatting..."
        if file -s /dev/$MODELS_VOL | grep -q "data"; then
            echo "  ❌ Volume appears empty or not formatted"
            exit 1
        fi
    }
else
    echo "  ✅ /mnt/models already mounted"
fi

# Setup output on ephemeral Instance Store (3.5TB on G5 instances)
echo ""
echo "📦 Setting up output on ephemeral storage..."

# Check if Instance Store is available at /opt/dlami/nvme
if [ -d "/opt/dlami/nvme" ]; then
    EPHEMERAL_PATH="/opt/dlami/nvme"
elif [ -d "/mnt/ephemeral" ]; then
    EPHEMERAL_PATH="/mnt/ephemeral"
else
    # Try to find and mount instance store
    INSTANCE_STORE=$(lsblk -d -n -o NAME,SIZE | grep -E '[0-9]T' | head -1 | awk '{print $1}')
    if [ -n "$INSTANCE_STORE" ]; then
        echo "  Found instance store: /dev/$INSTANCE_STORE"
        sudo mkdir -p /opt/dlami/nvme 2>/dev/null || true
        if ! mountpoint -q /opt/dlami/nvme; then
            sudo mount /dev/$INSTANCE_STORE /opt/dlami/nvme 2>/dev/null || true
        fi
        EPHEMERAL_PATH="/opt/dlami/nvme"
    else
        echo "  ⚠️  No instance store found, using /mnt/output on root"
        sudo mkdir -p /mnt/output 2>/dev/null || true
        EPHEMERAL_PATH=""
    fi
fi

if [ -n "$EPHEMERAL_PATH" ]; then
    # Create output directory on ephemeral storage
    sudo mkdir -p "$EPHEMERAL_PATH/output" 2>/dev/null || true

    # Create symlink /mnt/output -> ephemeral/output
    echo "  Creating symlink /mnt/output -> $EPHEMERAL_PATH/output"
    sudo rm -f /mnt/output 2>/dev/null || true
    sudo ln -sf "$EPHEMERAL_PATH/output" /mnt/output
fi

# Set permissions
sudo chown -R ubuntu:ubuntu /mnt/models 2>/dev/null || true
sudo chown -R ubuntu:ubuntu /mnt/output 2>/dev/null || true
if [ -n "$EPHEMERAL_PATH" ]; then
    sudo chown -R ubuntu:ubuntu "$EPHEMERAL_PATH/output" 2>/dev/null || true
fi

echo ""
echo "📊 Storage status:"
echo "  Models (EBS 500GB):"
df -h /mnt/models 2>/dev/null || echo "    Not mounted"
echo ""
echo "  Output (Ephemeral):"
df -h /mnt/output 2>/dev/null || echo "    Not mounted"
echo ""
echo "✅ Storage ready"
