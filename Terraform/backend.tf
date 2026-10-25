
terraform {
  backend "s3" {
    bucket       = "terraform-state-bucket-131"
    key          = "Gitops/1#/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}

