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

# EBS volume for video output
resource "aws_ebs_volume" "output" {
  availability_zone = data.aws_availability_zones.available.names[0]
  size              = var.output_volume_size
  type              = "gp3"
  iops              = 3000
  throughput        = 125
  encrypted         = true

  tags = {
    Name    = "${var.project_name}-output-volume"
    Project = var.project_name
    Purpose = "Generated video storage (will be copied to local via SSH)"
  }
}
