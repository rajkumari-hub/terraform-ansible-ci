
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }

    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_ssm_parameter" "amazon_linux_2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_security_group" "frontend" {
  name_prefix = "ci-frontend-"
  description = "Frontend HTTP and restricted SSH"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from administrator"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ci-frontend-sg"
  }
}

resource "aws_security_group" "backend" {
  name_prefix = "ci-backend-"
  description = "Backend Netdata and restricted SSH"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "Netdata only from frontend"
    from_port       = 19999
    to_port         = 19999
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend.id]
  }

  ingress {
    description = "SSH from administrator"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ci-backend-sg"
  }
}

resource "aws_instance" "frontend" {
  ami                         = data.aws_ssm_parameter.amazon_linux_2023.value
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = data.aws_subnets.default.ids[0]
  vpc_security_group_ids      = [aws_security_group.frontend.id]
  associate_public_ip_address = true

  tags = {
    Name = "c8.local"
    Hostname = "c8.local"
    Role = "frontend"
  }
}

resource "aws_instance" "backend" {
  ami                         = var.ubuntu_2104_ami_id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = data.aws_subnets.default.ids[0]
  vpc_security_group_ids      = [aws_security_group.backend.id]
  associate_public_ip_address = true

  tags = {
    Name = "u21.local"
    Hostname = "u21.local"
    Role = "backend"
  }
}

resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../ansible/inventory.ini"

  content = <<-EOT
[frontend]
c8.local ansible_host=${aws_instance.frontend.public_ip} ansible_user=ec2-user ansible_ssh_private_key_file=${var.ssh_private_key_path}

[backend]
u21.local ansible_host=${aws_instance.backend.public_ip} ansible_user=${var.ubuntu_2104_username} ansible_ssh_private_key_file=${var.ssh_private_key_path}

[all:vars]
ansible_python_interpreter=auto_silent
EOT
}

