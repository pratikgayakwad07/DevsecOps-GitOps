#!/usr/bin/env bash
# setup-iam-oidc.sh
# Creates (or updates) the GitHub Actions OIDC IAM role from scratch.
# Run this ONCE from a terminal with AWS admin credentials before the
# first GitHub Actions CI run.
#
# Usage:
#   AWS_PROFILE=your-profile bash setup-iam-oidc.sh
#   -- OR --
#   aws configure   # then run:
#   bash setup-iam-oidc.sh

set -euo pipefail

AWS_ACCOUNT_ID="122384809512"
AWS_REGION="us-east-1"
ROLE_NAME="github-actions-blog-app-role"

# Exact OIDC subject as reported by GitHub
# Format: repo:<owner>@<owner-id>/<repo>@<installation-id>
OIDC_SUB="repo:pratikgayakwad07@148746650/DevsecOps-GitOps@1421825825"

OIDC_PROVIDER_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"

echo "==> Verifying AWS identity"
aws sts get-caller-identity --region "${AWS_REGION}"

# -----------------------------------------------------------------------
# 1. Create OIDC provider (safe to run if it already exists — will error
#    with EntityAlreadyExists which we ignore)
# -----------------------------------------------------------------------
echo "==> Creating GitHub OIDC provider (ignoring EntityAlreadyExists)"
aws iam create-open-id-connect-provider \
  --url "https://token.actions.githubusercontent.com" \
  --client-id-list "sts.amazonaws.com" \
  --thumbprint-list "6938fd4d98bab03faadb97b34396831e3780aea1" 2>&1 || true

# -----------------------------------------------------------------------
# 2. Write the trust policy using the exact OIDC subject
# -----------------------------------------------------------------------
TRUST_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "${OIDC_PROVIDER_ARN}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "${OIDC_SUB}"
        }
      }
    }
  ]
}
EOF
)

# -----------------------------------------------------------------------
# 3. Create or update the IAM role
# -----------------------------------------------------------------------
if aws iam get-role --role-name "${ROLE_NAME}" &>/dev/null; then
  echo "==> Role exists — updating trust policy"
  aws iam update-assume-role-policy \
    --role-name "${ROLE_NAME}" \
    --policy-document "${TRUST_POLICY}"
else
  echo "==> Creating IAM role: ${ROLE_NAME}"
  aws iam create-role \
    --role-name "${ROLE_NAME}" \
    --assume-role-policy-document "${TRUST_POLICY}" \
    --description "GitHub Actions OIDC role for DevsecOps-GitOps CI/CD"
fi

# -----------------------------------------------------------------------
# 4. Attach ECR push permissions
# -----------------------------------------------------------------------
echo "==> Attaching ECR push policy"
ECR_POLICY=$(cat <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ECRPush",
      "Effect": "Allow",
      "Action": [
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:DescribeRepositories",
        "ecr:ListImages",
        "ecr:DescribeImages"
      ],
      "Resource": [
        "arn:aws:ecr:us-east-1:122384809512:repository/prod/backend-blog-app",
        "arn:aws:ecr:us-east-1:122384809512:repository/prod/blog-app"
      ]
    },
    {
      "Sid": "ECRAuth",
      "Effect": "Allow",
      "Action": "ecr:GetAuthorizationToken",
      "Resource": "*"
    }
  ]
}
EOF
)

# Delete existing inline policy first (ignore error if it doesn't exist)
aws iam delete-role-policy --role-name "${ROLE_NAME}" --policy-name "ecr-push-policy" 2>/dev/null || true
aws iam put-role-policy \
  --role-name "${ROLE_NAME}" \
  --policy-name "ecr-push-policy" \
  --policy-document "${ECR_POLICY}"

# -----------------------------------------------------------------------
# 5. Attach EKS describe permission
# -----------------------------------------------------------------------
echo "==> Attaching EKS policy"
EKS_POLICY=$(cat <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["eks:DescribeCluster", "eks:ListClusters"],
      "Resource": "*"
    }
  ]
}
EOF
)
aws iam delete-role-policy --role-name "${ROLE_NAME}" --policy-name "eks-deploy-policy" 2>/dev/null || true
aws iam put-role-policy \
  --role-name "${ROLE_NAME}" \
  --policy-name "eks-deploy-policy" \
  --policy-document "${EKS_POLICY}"

# -----------------------------------------------------------------------
# 6. Attach CloudWatch read
# -----------------------------------------------------------------------
echo "==> Attaching CloudWatch read policy"
aws iam attach-role-policy \
  --role-name "${ROLE_NAME}" \
  --policy-arn "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess" 2>/dev/null || true

# -----------------------------------------------------------------------
# 7. Create ECR repositories if they don't exist
# -----------------------------------------------------------------------
echo "==> Ensuring ECR repositories exist"
for REPO in "prod/backend-blog-app" "prod/blog-app"; do
  if ! aws ecr describe-repositories --repository-names "${REPO}" --region "${AWS_REGION}" &>/dev/null; then
    echo "  Creating ECR repo: ${REPO}"
    aws ecr create-repository \
      --repository-name "${REPO}" \
      --image-tag-mutability MUTABLE \
      --image-scanning-configuration scanOnPush=true \
      --region "${AWS_REGION}"
  else
    echo "  ECR repo already exists: ${REPO}"
  fi
done

# -----------------------------------------------------------------------
# 8. Final verification
# -----------------------------------------------------------------------
echo ""
echo "==> Verification"
ROLE_ARN=$(aws iam get-role --role-name "${ROLE_NAME}" --query "Role.Arn" --output text)
echo "  Role ARN: ${ROLE_ARN}"
echo ""
echo "  Trust policy:"
aws iam get-role --role-name "${ROLE_NAME}" --query "Role.AssumeRolePolicyDocument" --output json
echo ""
echo "  Inline policies:"
aws iam list-role-policies --role-name "${ROLE_NAME}" --query "PolicyNames" --output text
echo ""
echo "==> Done. Add this to your GitHub Actions workflow:"
echo "    ROLE_ARN: \"${ROLE_ARN}\""
echo ""
echo "  The workflow is already configured with the correct ROLE_ARN."
echo "  Re-run the failed GitHub Actions workflow to test."
