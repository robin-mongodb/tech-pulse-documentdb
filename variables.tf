variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-2"
}

variable "project_name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "docdb-sa-session"
}

variable "docdb_instance_class" {
  description = "DocumentDB instance class, e.g. db.t3.medium, db.r6g.large, db.r6g.xlarge"
  type        = string
}

variable "docdb_master_username" {
  type    = string
  default = "docdbadmin"
}

variable "docdb_master_password" {
  description = "DocumentDB master password. Min 8 chars, no '/', '\"', or '@'."
  type        = string
  sensitive   = true
}

variable "ec2_key_name" {
  description = "Name of an EXISTING AWS EC2 key pair (created in the AWS Console). Must be in the same region as var.aws_region."
  type        = string
}

variable "go_version" {
  description = "Go version to install from the official tarball"
  type        = string
  default     = "1.22.5"
}

