terraform {
  backend "s3" {
    bucket  = "jhbaik-tfstates"
    encrypt = true
    key     = "20242R0136COSE44400/00_ec2.tfstate"
    region  = "ap-northeast-2"
  }
}

provider "aws" {
  region = "ap-northeast-2"

  default_tags {
    tags = local.tags
  }
}

locals {
  name = "COSE444"
  tags = {
    Name = local.name
  }
}

resource "aws_key_pair" "key" {
  key_name_prefix = local.name
  public_key      = file("./bjh_2023.pub")
}

resource "aws_security_group" "ec2" {
  name_prefix = local.name

  dynamic "ingress" {
    for_each = toset([22, 80, 443])

    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] // AWS

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-*"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}


module "ec2-instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.7.1"

  instance_type          = "t4g.medium"
  key_name               = aws_key_pair.key.key_name
  vpc_security_group_ids = [aws_security_group.ec2.id]

  ami = data.aws_ami.ubuntu.image_id
}

resource "aws_eip" "eip" {

}
resource "aws_eip_association" "eip" {
  allocation_id = aws_eip.eip.allocation_id
  instance_id   = module.ec2-instance.id
}
output "eip" {
  value = aws_eip.eip.public_ip
}