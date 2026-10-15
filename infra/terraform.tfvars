aws_region     = "us-east-1"
environment    = "prod"
vpc_name       = "blog-prod-vpc"
vpc_cidr       = "10.0.0.0/16"
azs            = ["us-east-1a", "us-east-1b", "us-east-1c"]
public_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
private_subnets = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]

cluster_name    = "blog-prod-eks"
cluster_version = "1.34"
instance_types  = ["t3.small"]
desired_size    = 2
min_size        = 2
max_size        = 4

github_org           = "pratikgayakwad07"
github_repo          = "blog-app-eks-devsecops"
github_owner_id      = "148746650"
github_repository_id = "1420392539"
