############################################
# variables (inputs to this module)
############################################
variable "subnet_id"     { type = string }
variable "vpc_id"        { type = string }
variable "instance_type" { type = string }
variable "ami_id"        { type = string }
variable "environment"   { type = string }

############################################
# security group
############################################
resource "aws_security_group" "web_sg" {
  vpc_id = var.vpc_id
  name   = "sre-${var.environment}-web-sg"

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sre-${var.environment}-sg"
  }
}

############################################
# EC2 instance
############################################
resource "aws_instance" "web" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  user_data = <<-EOF
    #!/bin/bash
    set -euo pipefail

    dnf update -y
    dnf install -y nginx python3 python3-pip

    # --- Flask app on 127.0.0.1:8080 ---
    mkdir -p /opt/app
    cat << 'APP' > /opt/app/app.py
    from flask import Flask, jsonify
    app = Flask(__name__)

    @app.route("/api")
    def api_root():
        return jsonify(message="Hello from Flask API - ${var.environment}", env="${var.environment}")

    @app.route("/api/health")
    def health():
        return jsonify(status="ok")

    if __name__ == "__main__":
        app.run(host="127.0.0.1", port=8080)
    APP

    python3 -m pip install --upgrade pip
    pip3 install flask

    # systemd service to keep Flask running
    cat << 'UNIT' > /etc/systemd/system/flask.service
    [Unit]
    Description=Flask API
    After=network.target

    [Service]
    User=root
    WorkingDirectory=/opt/app
    ExecStart=/usr/bin/python3 /opt/app/app.py
    Restart=always
    RestartSec=5
    StandardOutput=journal
    StandardError=journal

    [Install]
    WantedBy=multi-user.target
    UNIT

    systemctl daemon-reload
    systemctl enable flask
    systemctl start flask

    # --- Nginx config ---
    # Static homepage at /
    mkdir -p /usr/share/nginx/html
    cat << 'INDEX' > /usr/share/nginx/html/index.html
    <!doctype html>
    <html>
      <head><meta charset="utf-8"><title>SRE EC2</title></head>
      <body style="font-family: system-ui, Arial">
        <h1>Welcome to SRE EC2 (${var.environment})</h1>
        <p>Static page served by <b>Nginx</b>.</p>
        <p>Try the API: <a href="/api">/api</a> &middot; <a href="/api/health">/api/health</a></p>
      </body>
    </html>
    INDEX

    # Reverse proxy /api -> Flask on 127.0.0.1:8080
    mkdir -p /etc/nginx/conf.d
    cat << 'CONF' > /etc/nginx/conf.d/app.conf
    server {
      listen 80 default_server;
      listen [::]:80 default_server;
      server_name _;

      # Static root for /
      root /usr/share/nginx/html;
      index index.html;

      location /api/ {
        proxy_pass         http://127.0.0.1:8080/; # note trailing slash to keep paths
        proxy_http_version 1.1;
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
        proxy_connect_timeout 5s;
        proxy_read_timeout  60s;
      }
    }
    CONF

    # Remove default welcome page if present and (re)start nginx
    rm -f /usr/share/nginx/html/*.png /usr/share/nginx/html/*.svg /usr/share/nginx/html/50x.html || true
    systemctl enable nginx
    systemctl restart nginx
  EOF

  tags = { Name = "sre-${var.environment}-ec2" }
}
############################################
# outputs (returned to root module)
############################################
output "public_ip" {
  value = aws_instance.web.public_ip
}
