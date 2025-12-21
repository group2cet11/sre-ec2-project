#############################################
# terraform/modules/compute/main.tf
#############################################

############################
# Security Group
############################
resource "aws_security_group" "ec2_sg" {
  name        = "${var.name_prefix}-ec2-sg"
  description = "Security group for ${var.name_prefix} EC2 instance"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow Node Exporter from VPC"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-ec2-sg"
  }
}

############################
# EC2 Instance
############################
resource "aws_instance" "app" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  key_name                    = var.key_name
  associate_public_ip_address = true

  # Forces re-run if script changes
  user_data_replace_on_change = true

  user_data = <<-EOF
    #!/bin/bash
    set -eux

    # Install Node Exporter (centralized, versioned)
    curl -fsSL https://raw.githubusercontent.com/mjmak0001/sre-ec2-project/main/scripts/install-node-exporter.sh | bash

    # Optional demo page
    if [ -d /var/www/html ]; then
      echo "Hello SRE World! - ${var.environment} Environment" > /var/www/html/index.html
    fi
  EOF

  tags = {
    Name        = "${var.name_prefix}-ec2"
    Environment = var.environment
    Monitor     = "true"
  }
}

############################
# Outputs
############################
output "public_ip" {
  value       = aws_instance.app.public_ip
  description = "Public IP of the EC2 instance"
}
