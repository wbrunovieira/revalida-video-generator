# terraform/outputs.tf

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.video_generation.id
}

output "instance_type" {
  description = "Instance type (GPU configuration)"
  value       = aws_instance.video_generation.instance_type
}

output "public_ip" {
  description = "Elastic IP address of the server"
  value       = aws_eip.video_generation.public_ip
}

output "availability_zone" {
  description = "Availability zone where instance is running"
  value       = aws_instance.video_generation.availability_zone
}

output "ami_id" {
  description = "AMI ID used for the instance"
  value       = aws_instance.video_generation.ami
}

output "ami_name" {
  description = "Name of the Deep Learning AMI used"
  value       = data.aws_ami.deep_learning_ubuntu.name
}

output "ssh_command" {
  description = "SSH command to connect to the server"
  value       = "ssh -i ${pathexpand(var.private_key_path)} ubuntu@${aws_eip.video_generation.public_ip}"
}

output "scp_download_command" {
  description = "SCP command to download videos"
  value       = "scp -i ${pathexpand(var.private_key_path)} ubuntu@${aws_eip.video_generation.public_ip}:/mnt/output/*.mp4 ."
}

output "models_volume_id" {
  description = "EBS volume ID for models storage"
  value       = aws_ebs_volume.models.id
}

output "output_volume_id" {
  description = "EBS volume ID for video output"
  value       = aws_ebs_volume.output.id
}

output "instance_cost_estimate" {
  description = "Estimated hourly cost"
  value = var.use_spot_instance ? (
    var.instance_type == "g5.12xlarge" ? "~$1.70/hour (Spot)" :
    var.instance_type == "g5.24xlarge" ? "~$2.40/hour (Spot)" :
    var.instance_type == "g5.48xlarge" ? "~$4.80/hour (Spot)" :
    "Check AWS pricing"
    ) : (
    var.instance_type == "g5.12xlarge" ? "~$5.67/hour (On-Demand)" :
    var.instance_type == "g5.24xlarge" ? "~$8.14/hour (On-Demand)" :
    var.instance_type == "g5.48xlarge" ? "~$16.28/hour (On-Demand)" :
    "Check AWS pricing"
  )
}

output "gpu_info" {
  description = "GPU configuration information"
  value = var.instance_type == "g5.12xlarge" ? "4x NVIDIA A10G (24GB each) = 96GB VRAM total" : (
    var.instance_type == "g5.24xlarge" ? "4x NVIDIA A10G (24GB each) = 96GB VRAM total" :
    var.instance_type == "g5.48xlarge" ? "8x NVIDIA A10G (24GB each) = 192GB VRAM total" :
    "Unknown GPU configuration"
  )
}

output "setup_instructions" {
  description = "Next steps after Terraform apply"
  value = <<-EOT

    ========================================
    🎉 Video Generation Server Created!
    ========================================

    📍 Instance Details:
       - Type: ${aws_instance.video_generation.instance_type}
       - GPUs: ${var.instance_type == "g5.12xlarge" ? "4x NVIDIA A10G (96GB VRAM)" : "Check gpu_info output"}
       - Cost: ${var.use_spot_instance ? "~$1.70/hour (Spot)" : "~$5.67/hour (On-Demand)"}

    🔑 Connect via SSH:
       ssh -i ${pathexpand(var.private_key_path)} ubuntu@${aws_eip.video_generation.public_ip}

    📦 Next Steps:
       1. SSH into the server (command above)

       2. Mount EBS volumes:
          sudo mkfs -t ext4 /dev/nvme1n1  # Models volume (only first time)
          sudo mkfs -t ext4 /dev/nvme2n1  # Output volume (only first time)
          sudo mount /dev/nvme1n1 /mnt/models
          sudo mount /dev/nvme2n1 /mnt/output

          # Make mounts permanent:
          echo '/dev/nvme1n1 /mnt/models ext4 defaults,nofail 0 2' | sudo tee -a /etc/fstab
          echo '/dev/nvme2n1 /mnt/output ext4 defaults,nofail 0 2' | sudo tee -a /etc/fstab

       3. Activate Python environment:
          source /home/ubuntu/video-generation/venv/bin/activate

       4. Download AI models (example HunyuanVideo):
          cd /mnt/models
          huggingface-cli download tencent/HunyuanVideo --local-dir HunyuanVideo

       5. Check GPU:
          nvidia-smi

       6. Generate videos (after model setup)

       7. Copy videos to your local machine:
          scp -i ${pathexpand(var.private_key_path)} ubuntu@${aws_eip.video_generation.public_ip}:/mnt/output/*.mp4 ~/Downloads/

    💰 Cost Optimization:
       - Stop instance when not in use: $0/hour
       - EBS volumes still cost: ~$0.08/GB/month (~$56/month for 700GB)
       - Use Spot instances for 70% savings

    📹 Storage:
       - Models: ${var.models_volume_size}GB at /mnt/models
       - Output: ${var.output_volume_size}GB at /mnt/output

    ========================================
  EOT
}
