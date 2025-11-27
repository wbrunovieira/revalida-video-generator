# Video Generation Server - Bash Aliases & Functions
# Source: ~/.bashrc-video-gen

# ==========================================
# Quick Navigation
# ==========================================
alias cdmodels='cd /mnt/models'
alias cdoutput='cd /mnt/output'
alias cdapp='cd /home/ubuntu/video-generation'

# ==========================================
# Python Environment
# ==========================================
alias venv='source /home/ubuntu/video-generation/venv/bin/activate'
alias piplist='source /home/ubuntu/video-generation/venv/bin/activate && pip list'

# ==========================================
# System Monitoring
# ==========================================
alias gpuwatch='watch -n 1 nvidia-smi'
alias diskspace='df -h | grep -E "Filesystem|/mnt|/$"'
alias meminfo='free -h'

# ==========================================
# Model Management
# ==========================================
alias lsmodels='ls -lh /mnt/models'
alias lsoutput='ls -lh /mnt/output'
alias countvideos='ls -1 /mnt/output/*.mp4 2>/dev/null | wc -l'

# ==========================================
# Useful Functions
# ==========================================

# Show GPU usage in a clean format
gpustatus() {
    if command -v nvidia-smi &> /dev/null; then
        nvidia-smi --query-gpu=index,name,temperature.gpu,utilization.gpu,memory.used,memory.total --format=csv
    else
        echo "No GPU detected"
    fi
}

# Calculate total size of models
modelsize() {
    echo "📦 Models Storage Usage:"
    du -sh /mnt/models/* 2>/dev/null | sort -h
    echo ""
    echo "Total: $(du -sh /mnt/models 2>/dev/null | cut -f1)"
}

# Calculate total size of generated videos
outputsize() {
    echo "📹 Output Storage Usage:"
    du -sh /mnt/output/* 2>/dev/null | sort -h
    echo ""
    echo "Total: $(du -sh /mnt/output 2>/dev/null | cut -f1)"
}

# Quick system overview
sysinfo() {
    echo "=========================================="
    echo "SYSTEM OVERVIEW"
    echo "=========================================="
    echo ""
    echo "🖥️  Hostname: $(hostname)"
    echo "📍 IP: $(hostname -I | awk '{print $1}')"
    echo "⏰ Uptime: $(uptime -p)"
    echo ""
    echo "💾 Disk:"
    df -h / | tail -1
    echo ""
    echo "🧠 Memory:"
    free -h | grep Mem
    echo ""
    if command -v nvidia-smi &> /dev/null; then
        echo "🎮 GPU:"
        nvidia-smi --query-gpu=name,memory.used,memory.total --format=csv,noheader
    fi
    echo "=========================================="
}

# Download video model with huggingface-cli
dlmodel() {
    if [ -z "$1" ]; then
        echo "Usage: dlmodel <model-repo-name>"
        echo ""
        echo "Examples:"
        echo "  dlmodel tencent/HunyuanVideo"
        echo "  dlmodel feizhengcong/Ovi"
        echo "  dlmodel THUDM/CogVideoX-5b"
        return 1
    fi

    MODEL_NAME=$(basename $1)
    echo "📥 Downloading $1 to /mnt/models/$MODEL_NAME"

    cd /mnt/models
    source /home/ubuntu/video-generation/venv/bin/activate
    huggingface-cli download $1 --local-dir $MODEL_NAME
}

# Copy videos to local machine (shows SCP command)
copyvideo() {
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    echo "📹 To copy videos to your local machine, run this on YOUR LOCAL terminal:"
    echo ""
    echo "scp -i ~/.ssh/id_rsa ubuntu@${LOCAL_IP}:/mnt/output/*.mp4 ~/Downloads/"
    echo ""
    echo "Or for a specific video:"
    echo "scp -i ~/.ssh/id_rsa ubuntu@${LOCAL_IP}:/mnt/output/video.mp4 ~/Downloads/"
}

# ==========================================
# Startup Message
# ==========================================
echo ""
echo "🎬 Video Generation Server Ready!"
echo "   Type 'video-status' for system overview"
echo "   Type 'sysinfo' for quick system info"
echo "   Type 'venv' to activate Python environment"
echo ""
