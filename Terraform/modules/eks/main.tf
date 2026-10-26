module "eks" {

  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  cluster_endpoint_public_access = true

  enable_cluster_creator_admin_permissions = true

  vpc_id = var.vpc_id

  subnet_ids = var.private_subnets

  enable_irsa = true

  cluster_enabled_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  eks_managed_node_groups = {

    blog_nodes = {

      desired_size = 2
      min_size = 2
      max_size = 3
      instance_types = [var.instance_type]
      capacity_type = "ON_DEMAND"
      disk_size = 30

      labels = {
        Environment = var.environment
      }

      tags = {
        Name = "blog-node"
      }
    }
  }

  tags = {

    Environment = var.environment

    Terraform = "true"

    Project = "Simple-Blog-App"
  }

}
