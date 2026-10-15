module "vpc" {
  source = "./modules/vpc"

  environment     = var.environment
  vpc_name        = var.vpc_name
  vpc_cidr        = var.vpc_cidr
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
  azs             = var.azs
}

module "eks" {
  source = "./modules/eks"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs
  environment     = var.environment
  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnets
  github_actions_role_arn = module.oidc.role_arn
  instance_types  = var.instance_types
  desired_size    = var.desired_size
  min_size        = var.min_size
  max_size        = var.max_size
}

module "ecr" {
  source = "./modules/ecr"

  environment = var.environment
}

module "oidc" {
  source = "./modules/oidc"

  aws_region   = var.aws_region
  cluster_name         = var.cluster_name
  github_org           = var.github_org
  github_repo          = var.github_repo
  github_owner_id      = var.github_owner_id
  github_repository_id = var.github_repository_id
}
