terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  region = var.aws_region
}

# AMI ID mapping for different regions (Ubuntu 20.04 LTS)
locals {
  ami_ids = {
    us-east-1      = "ami-0c02fb55956c7d316"  # Ubuntu 20.04 LTS
    us-east-2      = "ami-0f924dc71d44d23e2"  # Ubuntu 20.04 LTS
    us-west-1      = "ami-0d382e80be7ffdae5"  # Ubuntu 20.04 LTS
    us-west-2      = "ami-03d5c68bab01f3496"  # Ubuntu 20.04 LTS
    eu-west-1      = "ami-0a8e758f5e873d1c1"  # Ubuntu 20.04 LTS
    eu-central-1   = "ami-05f7491af5eef733a"  # Ubuntu 20.04 LTS
    ap-southeast-1 = "ami-0c802847a7dd848c0"  # Ubuntu 20.04 LTS
    ap-northeast-1 = "ami-0df99b3a8349462c6"  # Ubuntu 20.04 LTS
  }
}

# Get default VPC
data "aws_vpc" "default" {
  default = true
}

# Get all subnets in default VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Get the first available subnet
data "aws_subnet" "selected" {
  id = data.aws_subnets.default.ids[0]
}

# Security Group
resource "aws_security_group" "flask_sg" {
  name        = "${var.project_name}-sg"
  description = "Security group for Flask monitoring dashboard"
  vpc_id      = data.aws_vpc.default.id

  # SSH access
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  # HTTP access
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  # HTTPS access
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  # Flask development port
  ingress {
    description = "Flask Development"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-security-group"
    Project = var.project_name
  }
}

# EC2 Instance (NO PROVISIONER)
resource "aws_instance" "flask_server" {
  ami                         = lookup(local.ami_ids, var.aws_region, local.ami_ids["us-east-1"])
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = data.aws_subnet.selected.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.flask_sg.id]

  # User data script to prepare the instance
  user_data = <<-EOF
              #!/bin/bash
              set -e
              
              # Update system
              apt-get update
              apt-get upgrade -y
              
              # Install required packages
              apt-get install -y \
                python3 \
                python3-pip \
                nginx \
                supervisor \
                git \
                curl \
                wget \
                unzip
              
              # Install Python packages
              pip3 install flask gunicorn
              
              # Create application user and directory
              mkdir -p /home/ubuntu/flask-dashboard
              chown ubuntu:ubuntu /home/ubuntu/flask-dashboard
              
              # Signal that user data script completed
              touch /home/ubuntu/user_data_completed
              EOF

  tags = {
    Name    = "${var.project_name}-server"
    Project = var.project_name
  }
}

# Elastic IP for consistent access
resource "aws_eip" "flask_eip" {
  instance = aws_instance.flask_server.id
  domain   = "vpc"

  tags = {
    Name    = "${var.project_name}-eip"
    Project = var.project_name
  }

  depends_on = [aws_instance.flask_server]
}
