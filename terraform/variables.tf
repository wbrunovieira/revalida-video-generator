# terraform/variables.tf

variable "aws_region" {
  description = "AWS region for GPU instances"
  type        = string
  default     = "us-east-1" # G5 instances widely available
}

variable "aws_profile" {
  description = "AWS CLI profile"
  type        = string
  default     = "default"
}

variable "project_name" {
  description = "Project name for tagging"
  type        = string
  default     = "video-generation"
}

variable "key_name" {
  description = "Name for the EC2 key pair in AWS"
  type        = string
  default     = "video-generation-key"
}

variable "public_key_path" {
  description = "Path to SSH public key"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "private_key_path" {
  description = "Path to SSH private key"
  type        = string
  default     = "~/.ssh/id_rsa"
}

# GPU Instance Configuration
variable "instance_type" {
  description = "GPU instance type"
  type        = string
  default     = "g5.12xlarge"
}

# Instance presets for easy switching
variable "instance_presets" {
  description = "Available instance configurations"
  type = map(object({
    type        = string
    gpus        = string
    vram_per_gpu = number
    description = string
    spot_price  = string
  }))
  default = {
    "g5" = {
      type         = "g5.12xlarge"
      gpus         = "4x A10G"
      vram_per_gpu = 24
      description  = "Standard - Ovi, CogVideoX, Wan 2.2"
      spot_price   = "~$1.70/h"
    }
    "p3dn" = {
      type         = "p3dn.24xlarge"
      gpus         = "8x V100"
      vram_per_gpu = 32
      description  = "Large models (32GB VRAM/GPU)"
      spot_price   = "~$10/h"
    }
  }
}

variable "use_spot_instance" {
  description = "Use Spot instances for 70% cost savings"
  type        = bool
  default     = true
}

variable "spot_max_price" {
  description = "Max price for Spot instance (empty = on-demand price)"
  type        = string
  default     = "" # Let AWS determine based on current spot price
}

# Storage Configuration
variable "root_volume_size" {
  description = "Root volume size in GB (for OS + software)"
  type        = number
  default     = 100
}

variable "models_volume_size" {
  description = "EBS volume size in GB for AI models"
  type        = number
  default     = 1500 # HunyuanVideo ~300GB + Ovi ~91GB + Wan ~30GB + CogVideoX ~50GB + extras (~$120/month)
}

# REMOVED: output_volume_size
# Videos now stored on ephemeral Instance Store (3.5TB)

# AMI Configuration
variable "ami_id" {
  description = "Deep Learning AMI with CUDA pre-installed (Ubuntu 22.04)"
  type        = string
  default     = "" # Will be fetched from AWS
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Change to your IP for security
}

# Note: Videos will be copied to local machine via SSH/SCP
# No S3 bucket needed
