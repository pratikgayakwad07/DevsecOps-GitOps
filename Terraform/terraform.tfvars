# Terraform variable values for the Simple Blog App on EKS
# Adjust as needed for dev / prod environments.

aws_region         = "us-east-1"

environment        = "dev"

# GitHub OIDC IAM role
role_name          = "github-actions-blog-app-role"
repository_pattern = "repo:pratikgayakwad07/blog-app-eks-devsecops:*"

# VPC configuration
vpc_name           = "blog-vpc"
vpc_cidr           = "10.0.0.0/16"
azs                = ["us-east-1a", "us-east-1b", "us-east-1c"]
public_subnets     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
private_subnets    = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

# EKS cluster configuration
cluster_name       = "blog-prod-eks"
cluster_version    = "1.29"
instance_type      = "t3.micro"

# ECR repository name (optional – used in the ecr module if you expose it later)
# ecr_repository_name = "blog-app-ecr"
