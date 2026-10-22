module "vpc" {
  source = "./modules/vpc"

  environment = var.environment
  vpc_name    = var.vpc_name
  vpc_cidr    = var.vpc_cidr
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
  azs = var.azs
  
}

module "eks" {

  source = "./modules/eks"

  cluster_name       = var.cluster_name
  cluster_version    = var.cluster_version
  environment        = var.environment

  vpc_id             = module.vpc.vpc_id
  private_subnets    = module.vpc.private_subnets
  instance_type      = var.instance_type

}

module "ecr" {
  source = "./modules/ecr"

  environment = var.environment
}