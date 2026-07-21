terraform {
  required_version = ">= 1.5.0"
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

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

locals {
  my_ip_cidr = "${trimspace(data.http.my_ip.response_body)}/32"
}

resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-ec2"
  description = "SSH into the SA benchmark host"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.my_ip_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Project = var.project_name }
}

resource "aws_security_group" "docdb" {
  name        = "${var.project_name}-docdb"
  description = "DocumentDB access from the EC2 SG only"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = 27017
    to_port         = 27017
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Project = var.project_name }
}

resource "aws_docdb_subnet_group" "this" {
  name       = "${var.project_name}-subnets"
  subnet_ids = data.aws_subnets.default.ids
  tags       = { Project = var.project_name }
}

resource "aws_docdb_cluster" "this" {
  cluster_identifier     = "${var.project_name}-cluster"
  engine                 = "docdb"
  engine_version         = "8.0.0"
  master_username        = var.docdb_master_username
  master_password        = var.docdb_master_password
  db_subnet_group_name   = aws_docdb_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.docdb.id]
  skip_final_snapshot    = true
  apply_immediately      = true
  storage_encrypted      = true
  tags                   = { Project = var.project_name }
}

resource "aws_docdb_cluster_instance" "this" {
  count              = 3
  identifier         = "${var.project_name}-instance-${count.index + 1}"
  cluster_identifier = aws_docdb_cluster.this.id
  instance_class     = var.docdb_instance_class
  tags               = { Project = var.project_name }
}

resource "aws_instance" "bench" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = "t3.micro"
  key_name                    = var.ec2_key_name
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  subnet_id                   = data.aws_subnets.default.ids[0]
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    docdb_endpoint = aws_docdb_cluster.this.endpoint
    docdb_port     = aws_docdb_cluster.this.port
    docdb_username = var.docdb_master_username
    go_version     = var.go_version
  })

  tags = { Project = var.project_name, Name = "${var.project_name}-bench" }

  depends_on = [aws_docdb_cluster_instance.this]
}

output "ssh_source_ip" {
  description = "The IP allowed to SSH into the EC2 (auto-detected at apply time)"
  value       = local.my_ip_cidr
}
