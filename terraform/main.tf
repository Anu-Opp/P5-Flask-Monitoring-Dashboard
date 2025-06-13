terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# AMI ID mapping for different regions
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

# Get default subnets
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Get default subnet (first one)
data "aws_subnet" "default" {
  id = data.aws_subnets.default.ids[0]
}

# Create Internet Gateway for default VPC if it doesn't exist
resource "aws_internet_gateway" "default" {
  vpc_id = data.aws_vpc.default.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# Get default route table
data "aws_route_table" "default" {
  vpc_id = data.aws_vpc.default.id
  filter {
    name   = "association.main"
    values = ["true"]
  }
}

# Add route to internet gateway in default route table
resource "aws_route" "default_route" {
  route_table_id         = data.aws_route_table.default.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.default.id
}

# Security Group
resource "aws_security_group" "flask_sg" {
  name_prefix = "${var.project_name}-sg"
  description = "Security group for Flask monitoring dashboard"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Flask Development"
    from_port   = 5000
    to_port     = 5000
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
    Name = "${var.project_name}-security-group"
  }
}

# EC2 Instance
resource "aws_instance" "flask_server" {
  ami                    = lookup(local.ami_ids, var.aws_region, local.ami_ids["us-east-1"])
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = data.aws_subnet.default.id

  vpc_security_group_ids = [aws_security_group.flask_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y python3 python3-pip nginx
              pip3 install flask gunicorn
              EOF

  tags = {
    Name = "${var.project_name}-server"
  }

  depends_on = [aws_internet_gateway.default]
}

# Elastic IP
resource "aws_eip" "flask_eip" {
  instance = aws_instance.flask_server.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-eip"
  }

  depends_on = [aws_internet_gateway.default, aws_instance.flask_server]
}