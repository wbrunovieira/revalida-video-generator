# terraform/ansible.tf
# Ansible integration for automated server configuration

# Generate Ansible inventory from Terraform outputs
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/../ansible/inventory.tpl", {
    public_ip          = aws_eip.video_generation.public_ip
    instance_id        = aws_instance.video_generation.id
    instance_type      = aws_instance.video_generation.instance_type
    availability_zone  = aws_instance.video_generation.availability_zone
    models_volume_id   = aws_ebs_volume.models.id
    output_volume_id   = aws_ebs_volume.output.id
    key_name          = var.key_name
  })

  filename = "${path.module}/../ansible/inventory.yml"

  depends_on = [
    aws_eip.video_generation,
    aws_volume_attachment.models,
    aws_volume_attachment.output
  ]
}

# Wait for SSH to be ready
resource "null_resource" "wait_for_ssh" {
  triggers = {
    instance_id = aws_instance.video_generation.id
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for SSH to be ready on ${aws_eip.video_generation.public_ip}..."
      for i in {1..60}; do
        if ssh -o StrictHostKeyChecking=no \
               -o UserKnownHostsFile=/dev/null \
               -o ConnectTimeout=5 \
               -i ${pathexpand(var.private_key_path)} \
               ubuntu@${aws_eip.video_generation.public_ip} \
               "echo 'SSH Ready'" 2>/dev/null; then
          echo "SSH is ready!"
          exit 0
        fi
        echo "Attempt $i/60: Waiting for SSH..."
        sleep 10
      done
      echo "ERROR: SSH did not become ready in time"
      exit 1
    EOT
  }

  depends_on = [
    aws_eip.video_generation,
    local_file.ansible_inventory
  ]
}

# Run Ansible playbook to configure the server
resource "null_resource" "run_ansible" {
  triggers = {
    instance_id       = aws_instance.video_generation.id
    inventory_content = local_file.ansible_inventory.content
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "=========================================="
      echo "Running Ansible playbook..."
      echo "=========================================="

      cd ${path.module}/../ansible

      ANSIBLE_HOST_KEY_CHECKING=False \
      ansible-playbook \
        -i inventory.yml \
        playbook.yml \
        -v

      echo "=========================================="
      echo "Ansible configuration completed!"
      echo "=========================================="
    EOT
  }

  depends_on = [
    null_resource.wait_for_ssh
  ]
}

# Optional: Run Ansible on every apply (not just create)
# Uncomment if you want Ansible to run even when updating infrastructure
# resource "null_resource" "run_ansible_always" {
#   triggers = {
#     always_run = timestamp()
#   }
#
#   provisioner "local-exec" {
#     command = <<-EOT
#       cd ${path.module}/../ansible
#       ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventory.yml playbook.yml
#     EOT
#   }
#
#   depends_on = [null_resource.wait_for_ssh]
# }
