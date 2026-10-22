variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
}


variable "environment" {
  description = "Environment name"
  type        = string
}

variable "role_name" {
  description = "Name of the IAM role for GitHub OIDC"
  type        = string
  default     = "github-actions-blog-app-role"
}

variable "repository_pattern" {
  description = "Repository pattern for OIDC trust"
  type        = string
  default     = "repo:pratikgayakwad07/*:*"
}


variable "vpc_name" {
  description = "Name of the VPC"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "public_subnets" {
  description = "List of public subnet CIDR blocks"
  type        = list(string)
  
}

variable "private_subnets" {
  description = "List of private subnet CIDR blocks"
  type        = list(string)
}

variable "azs" {
  description = "List of availability zones"
  type        = list(string)
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "cluster_name" {
    description = "Name of the EKS cluster"
    type        = string
}

variable "cluster_version" {
    description = "Version of the EKS cluster"
    type        = string
}