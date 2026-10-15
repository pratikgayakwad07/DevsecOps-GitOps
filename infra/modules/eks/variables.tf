variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnets" {
  description = "Private subnet IDs"
  type        = list(string)
}

variable "github_actions_role_arn" {
  description = "IAM role used by GitHub Actions for deployment verification"
  type        = string
}

variable "instance_types" {
  description = "Instance types for managed node group"
  type        = list(string)
}

variable "desired_size" {
  description = "Desired node count"
  type        = number
}

variable "min_size" {
  description = "Min node count"
  type        = number
}

variable "max_size" {
  description = "Max node count"
  type        = number
}
