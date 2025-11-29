# terraform/storage.tf

# EBS volume for AI models
resource "aws_ebs_volume" "models" {
  availability_zone = data.aws_availability_zones.available.names[0]
  size              = var.models_volume_size
  type              = "gp3"
  iops              = 3000
  throughput        = 125
  encrypted         = true

  tags = {
    Name    = "${var.project_name}-models-volume"
    Project = var.project_name
    Purpose = "AI model storage"
  }
}

# REMOVED: aws_ebs_volume.output
# Videos now stored on ephemeral Instance Store (3.5TB)
# and synced to local via SSH (make sync-videos)
