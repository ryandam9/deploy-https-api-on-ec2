#-----------------------------------------------------------------------------#
# Create an EC2 Instance using Ubuntu Image                                   #
#   Following resources will be deployed:                                     #
#       - EC2 Instance                                                        #
#                                                                             #
# Prerequisites:                                                              #
#   - A Key pair key                                                          #
#-----------------------------------------------------------------------------#
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.26.0"
    }
  }

  required_version = ">= 1.6.4"
}

provider "aws" {
  region = "ap-southeast-2"
}

#-----------------------------------------------------------------------------#
# Varibles                                                                    #
#-----------------------------------------------------------------------------#
variable "instance_type" {
  description = "Type of EC2 Instance"
  type        = string
  default     = "t2.micro"
}

variable "key_pair_name" {
  description = "Key pair name"
  type        = string
  default     = "ray"
}

variable "public_key_file_name" {
  description = "Location of public key file"
  type        = string
  default     = "../keys/id_rsa.pub"
}

#-----------------------------------------------------------------------------#
# Locals
#-----------------------------------------------------------------------------#
locals {
  inbound_ports = [22, 80, 443]
  user_data     = file("../working_dir/bootstrap.yaml")
  name          = "ex-${basename(path.cwd)}"

  tags = {
    Name       = local.name
    Example    = local.name
  }
}

#-----------------------------------------------------------------------------#
# Data
#-----------------------------------------------------------------------------#
# Find latest Ubuntu AMI
# https://ubuntu.com/server/docs/cloud-images/amazon-ec2
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  name_regex  = "^.*22.04.*$"

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "hypervisor"
    values = ["xen"]
  }

  filter {
    name   = "creation-date"
    values = ["2023-09-*"]
  }
}

#-----------------------------------------------------------------------------#
# Resources
#-----------------------------------------------------------------------------#
# Security group to accept traffic from the internet
# on http & https
resource "aws_security_group" "sg_webserver" {
  name        = "webserver-sg"
  description = "Security Group for Web Servers"

  dynamic "ingress" {
    for_each = local.inbound_ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
  }
}

# Create a Key using locally generated public key
resource "aws_key_pair" "key_pair" {
  key_name   = var.key_pair_name
  public_key = trimspace(file(var.public_key_file_name))
}

# Spin up an EC2 instance
module "ec2-instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.5.0"

  name                        = local.name
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  vpc_security_group_ids      = [aws_security_group.sg_webserver.id]
  associate_public_ip_address = true
  disable_api_stop            = false
  create_iam_instance_profile = true
  user_data                   = local.user_data
  user_data_replace_on_change = true
  enable_volume_tags          = false
  key_name                    = aws_key_pair.key_pair.key_name
  tags                        = local.tags
  iam_role_description        = "IAM role for EC2 instance"
  iam_role_policies = {
    AdministratorAccess = "arn:aws:iam::aws:policy/AdministratorAccess"
  }
}

#-----------------------------------------------------------------------------#
# Outputs
#-----------------------------------------------------------------------------#
output "public_ip" {
  value       = module.ec2-instance.public_ip
  description = "The public IP address of the web server"
}