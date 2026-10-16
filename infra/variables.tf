# Variables used by Terraform.
# Most values are set in terraform.tfvars

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g., dev, prod)"
  type        = string
}

variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
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

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Version of the EKS cluster"
  type        = string
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "Public IPv4 CIDRs permitted to reach the EKS API endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "instance_types" {
  description = "List of EC2 instance types for EKS node group"
  type        = list(string)
}

variable "desired_size" {
  description = "Desired number of nodes in the node group"
  type        = number
}

variable "min_size" {
  description = "Minimum number of nodes in the node group"
  type        = number
}

variable "max_size" {
  description = "Maximum number of nodes in the node group"
  type        = number
}

variable "github_org" {
  description = "GitHub organization or username for OIDC"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name for OIDC trust"
  type        = string
}

variable "github_owner_id" {
  description = "Immutable GitHub owner ID used in the OIDC subject"
  type        = string
}

variable "github_repository_id" {
  description = "Immutable GitHub repository ID used in the OIDC subject"
  type        = string
}
