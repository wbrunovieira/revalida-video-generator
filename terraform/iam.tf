# terraform/iam.tf

# IAM Role for EC2 instance
resource "aws_iam_role" "video_generation_role" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name    = "${var.project_name}-ec2-role"
    Project = var.project_name
  }
}

# Attach SSM policy for remote management
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.video_generation_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# CloudWatch Logs policy
resource "aws_iam_role_policy" "cloudwatch_logs" {
  name = "${var.project_name}-cloudwatch-logs"
  role = aws_iam_role.video_generation_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Instance profile
resource "aws_iam_instance_profile" "video_generation_profile" {
  name = "${var.project_name}-instance-profile"
  role = aws_iam_role.video_generation_role.name

  tags = {
    Name    = "${var.project_name}-instance-profile"
    Project = var.project_name
  }
}
