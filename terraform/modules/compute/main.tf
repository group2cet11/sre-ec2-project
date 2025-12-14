#############################################
# terraform/modules/compute/main.tf (fixed user_data interpolation)
#############################################
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
    cidr_blocks = ["10.0.0.0/16"]  # Adjust if your VPC CIDR is different
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

resource "aws_instance" "app" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  key_name                    = var.key_name
  associate_public_ip_address = true

  user_data_replace_on_change = true

  user_data = <<-EOF
    #!/bin/bash
    set -e

    # Update system
    if command -v apt-get >/dev/null; then
      apt-get update -y
    elif command -v yum >/dev/null; then
      yum update -y
    fi

    # Install Node Exporter
    NODE_VERSION="1.8.2"
    wget -q https://github.com/prometheus/node_exporter/releases/download/v$$NODE_VERSION/node_exporter-$$NODE_VERSION.linux-amd64.tar.gz
    tar xvfz node_exporter-$$NODE_VERSION.linux-amd64.tar.gz
    mv node_exporter-$$NODE_VERSION.linux-amd64/node_exporter /usr/local/bin/
    rm -rf node_exporter*

    useradd --no-create-home --shell /bin/false node_exporter || true

    cat <<EOL > /etc/systemd/system/node-exporter.service
[Unit]
Description=Prometheus Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOL

    systemctl daemon-reload
    systemctl enable node-exporter
    systemctl start node-exporter

    # Simple web page
    echo "Hello SRE World! - ${var.environment} Environment" > /var/www/html/index.html
    EOF

  tags = {
    Name        = "${var.name_prefix}-ec2"
    Environment = var.environment
    Monitor     = "true"
  }
}

output "public_ip" {
  value       = aws_instance.app.public_ip
  description = "Public IP of the EC2 instance"
}
