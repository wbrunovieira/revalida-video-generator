# terraform/security_group.tf

resource "aws_security_group" "video_generation_sg" {
  name        = "${var.project_name}-sg"
  description = "Security group for video generation GPU server"
  vpc_id      = data.aws_vpc.default.id

  # SSH access
  ingress {
    description = "SSH from allowed IPs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  # Optional: Jupyter notebook access (for model experimentation)
  ingress {
    description = "Jupyter Notebook"
    from_port   = 8888
    to_port     = 8888
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  # Optional: TensorBoard/monitoring
  ingress {
    description = "TensorBoard/Monitoring"
    from_port   = 6006
    to_port     = 6006
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  # Allow all outbound traffic
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-sg"
    Project = var.project_name
  }
}
