variable "subnet_id" { type = string }
variable "vpc_id" { type = string }
variable "instance_type" { type = string }
variable "ami_id" { type = string }
variable "environment" { type = string }

resource "aws_security_group" "web_sg" {
  vpc_id = var.vpc_id
  name   = "sre-${var.environment}-web-sg"

  ingress { from_port = 80  to_port = 80  protocol = "tcp" cidr_blocks = ["0.0.0.0/0"] }
  ingress { from_port = 22  to_port = 22  protocol = "tcp" cidr_blocks = ["0.0.0.0/0"] }
  egress  { from_port = 0   to_port = 0   protocol = "-1"  cidr_blocks = ["0.0.0.0/0"] }

  tags = { Name = "sre-${var.environment}-sg" }
}

resource "aws_instance" "web" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  user_data = <<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y nginx python3 python3-pip
    systemctl enable nginx
    systemctl start nginx

    # Simple Flask app
    cat << 'APP' > /home/ec2-user/app.py
    from flask import Flask
    app = Flask(__name__)
    @app.route('/')
    def home():
        return "Hello from Flask on EC2 - ${var.environment}"
    if __name__ == '__main__':
        app.run(host='0.0.0.0', port=8080)
    APP

    pip install flask
    nohup python3 /home/ec2-user/app.py &
  EOF

  tags = { Name = "sre-${var.environment}-ec2" }
}

output "public_ip" {
  value = aws_instance.web.public_ip
}
