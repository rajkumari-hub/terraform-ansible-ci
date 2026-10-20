
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "key_name" {
  description = "Existing AWS EC2 key pair name"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Path to the private SSH key on the Terraform runner"
  type        = string
}

variable "ssh_allowed_cidr" {
  description = "Your public IP in CIDR format, e.g. 203.0.113.10/32"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ubuntu_2104_ami_id" {
  description = "Existing Ubuntu 21.04 AMI ID in the selected region"
  type        = string
}

variable "ubuntu_2104_username" {
  description = "SSH username for the selected Ubuntu AMI"
  type        = string
  default     = "ubuntu"
}

