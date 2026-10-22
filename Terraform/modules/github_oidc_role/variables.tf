variable "role_name" {
  description = "Name of the IAM role for GitHub OIDC"
  type        = string
}

variable "repository_pattern" {
  description = "IAM trust policy repository pattern, e.g., repo:owner/*:*"
  type        = string
}
