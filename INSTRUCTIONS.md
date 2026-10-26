# DevSecOps EKS Project — Setup & Operations Guide

This document is the single source of truth for deploying, operating, and
troubleshooting this project. Follow the phases in order on a fresh setup.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Architecture](#2-architecture)
3. [Prerequisites](#3-prerequisites)
4. [Phase 1 — Infrastructure (Terraform)](#4-phase-1--infrastructure-terraform)
5. [Phase 2 — GitHub OIDC & IAM](#5-phase-2--github-oidc--iam)
6. [Phase 3 — Deploy Supporting Tools](#6-phase-3--deploy-supporting-tools)
7. [Phase 4 — Deploy the Application](#7-phase-4--deploy-the-application)
8. [Phase 5 — CI/CD Pipeline](#8-phase-5--cicd-pipeline)
9. [Live URLs & Credentials](#9-live-urls--credentials)
10. [Validation Checklist](#10-validation-checklist)
11. [Troubleshooting](#11-troubleshooting)
12. [Teardown](#12-teardown)

---

## 1. Project Overview

**Application:** Simple Blog — React frontend, Node.js/Express backend, MySQL database.

**Stack:**

| Layer | Technology |
|-------|-----------|
| Infrastructure | AWS EKS 1.31, VPC, ECR, IAM — managed by Terraform |
| Container Build | Docker (multi-stage for frontend, single-stage for backend) |
| CI | GitHub Actions (OIDC — no static AWS keys) |
| CD | Argo CD (GitOps — deploys from this repo) |
| Monitoring | Prometheus + Grafana (kube-prometheus-stack) |
| Log Collection | AWS CloudWatch Container Insights + Fluent Bit |

---

## 2. Architecture

```
Developer pushes to main
        │
        ▼
GitHub Actions (.github/workflows/devsecops.yml)
  ├── Code checks + tests
  ├── Secret scan (Gitleaks)
  ├── Dependency audit (npm audit)
  ├── Dockerfile lint (hadolint)
  ├── Image scan (Trivy via Docker CLI)
  ├── Build & push images to ECR  ← OIDC auth, no stored keys
  └── Update image tag in Kubernetes manifests → git push
        │
        ▼
Argo CD detects manifest change → syncs to EKS
        │
        ▼
EKS Cluster: blog-prod-eks (us-east-1)
  Namespace: blog-app
    ├── frontend   (2 replicas, nginx, port 80)
    ├── backend    (2 replicas, Node.js, port 5003)
    └── mysql-0    (StatefulSet, EBS PVC 5Gi, us-east-1a)
        │
        ▼
AWS ALB Ingress (internet-facing)
  /        → frontend-service:80
  /api/*   → backend-service:5003

Monitoring (namespace: monitoring)
  ├── Prometheus  (scrapes all pods/nodes)
  ├── Grafana     (dashboard + alerts)
  └── Alertmanager

Logs (namespace: amazon-cloudwatch)
  ├── CloudWatch Agent  (Container Insights metrics)
  └── Fluent Bit        (pod logs → CloudWatch Logs)
```

---

## 3. Prerequisites

Install these tools before starting:

```bash
# Verify versions
aws --version          # AWS CLI v2
terraform version      # 1.12.x
kubectl version        # 1.30+
helm version           # 3.x
git --version
docker --version
```

Configure AWS credentials (admin user):

```bash
aws configure
# AWS Access Key ID: <your key>
# AWS Secret Access Key: <your secret>
# Default region: us-east-1
# Output format: json

# Verify
aws sts get-caller-identity
```

Expected output:
```json
{
  "UserId": "...",
  "Account": "122384809512",
  "Arn": "arn:aws:iam::122384809512:user/pratik"
}
```

---

## 4. Phase 1 — Infrastructure (Terraform)

> **Skip this phase if the cluster already exists** — run `aws eks list-clusters` to check.

```bash
cd Terraform

# Initialise backend (state stored in S3)
terraform init

# Review what will be created
terraform plan

# Apply — takes ~15 minutes (EKS cluster creation)
terraform apply -auto-approve
```

**What gets created:**

| Resource | Name |
|----------|------|
| VPC | blog-vpc (10.0.0.0/16) |
| EKS Cluster | blog-prod-eks (Kubernetes 1.31) |
| Node Group | 2× t3.medium in us-east-1a / us-east-1c |
| ECR — Backend | prod/backend-blog-app |
| ECR — Frontend | prod/blog-app |
| IAM Role (OIDC) | github-actions-blog-app-role |

After apply, configure kubectl:

```bash
aws eks update-kubeconfig --name blog-prod-eks --region us-east-1
kubectl get nodes   # both nodes should be Ready
```

---

## 5. Phase 2 — GitHub OIDC & IAM

This connects GitHub Actions to AWS without storing any credentials.

### 5a. Check the IAM role trust policy

The role must match the exact OIDC subject GitHub sends.
GitHub's subject format (immutable IDs, post-July 2026):
```
repo:pratikgayakwad07@148746650/DevsecOps-GitOps@1421825825:ref:refs/heads/main
```

The trust policy uses `StringLike` with a wildcard suffix to match any branch/event:
```
repo:pratikgayakwad07@148746650/DevsecOps-GitOps@1421825825:*
```

**Verify the live trust policy:**
```bash
aws iam get-role \
  --role-name github-actions-blog-app-role \
  --query "Role.AssumeRolePolicyDocument" \
  --output json
```

**If the role doesn't exist**, run the bootstrap script (only needed once):
```bash
bash setup-iam-oidc.sh
```

### 5b. Add the GitHub Actions role to EKS aws-auth

```bash
kubectl apply -f aws-auth-patch.yaml
# Veriy:
kubectl get configmap aws-auth -n kube-system -o yaml | grep -A3 "github-actions"
```

### 5c. Install EBS CSI driver (required for MySQL PVC)

```bash
# Attach policy to node role
aws iam attach-role-policy \
  --role-name blog_nodes-eks-node-group-<ID> \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy

# Install addon
aws eks create-addon \
  --cluster-name blog-prod-eks \
  --addon-name aws-ebs-csi-driver \
  --region us-east-1

# Verify (~2 minutes)
kubectl get pods -n kube-system | grep ebs-csi
```

---

## 6. Phase 3 — Deploy Supporting Tools

Run this script to install everything in one command:

```bash
bash monitoring/install-monitoring.sh
```

Or step by step:

### 6a. Install AWS Load Balancer Controller

```bash
# Create IAM policy
curl -o /tmp/lbc-policy.json \
  https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.9.1/docs/install/iam_policy.json

aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file:///tmp/lbc-policy.json

aws iam attach-role-policy \
  --role-name blog_nodes-eks-node-group-<ID> \
  --policy-arn arn:aws:iam::122384809512:policy/AWSLoadBalancerControllerIAMPolicy

# Install via Helm
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=blog-prod-eks \
  --set serviceAccount.create=true \
  --wait --timeout=5m

# Verify
kubectl get pods -n kube-system | grep aws-load-balancer
```

### 6b. Install Argo CD

```bash
kubectl create namespace argocd
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.12.0/manifests/install.yaml

# Wait for pods
kubectl wait --for=condition=available deployment/argocd-server \
  -n argocd --timeout=5m

# Expose as LoadBalancer
kubectl patch svc argocd-server -n argocd \
  --type=merge --patch-file <(echo '{"spec":{"type":"LoadBalancer"}}')

# Apply the blog-app Application
kubectl apply -f argocd/application.yaml

# Get admin password
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath='{.data.password}' | base64 -d && echo
```

### 6c. Install Prometheus + Grafana

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

kubectl create namespace monitoring

helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.adminPassword="Admin@123" \
  --wait --timeout=10m

# Expose as LoadBalancer
kubectl patch svc prometheus-grafana -n monitoring \
  --type=merge --patch-file <(echo '{"spec":{"type":"LoadBalancer"}}')
kubectl patch svc prometheus-kube-prometheus-prometheus -n monitoring \
  --type=merge --patch-file <(echo '{"spec":{"type":"LoadBalancer"}}')

# Apply alert rules
kubectl apply -f monitoring/prometheus-rules.yaml
```

### 6d. Install CloudWatch Container Insights

```bash
# Attach policy to node role
aws iam attach-role-policy \
  --role-name blog_nodes-eks-node-group-<ID> \
  --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy

kubectl create namespace amazon-cloudwatch

kubectl apply -f monitoring/cloudwatch/cloudwatch-agent-config.yaml
kubectl apply -f monitoring/cloudwatch/fluentbit-config.yaml

BASE=https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring
kubectl apply -f ${BASE}/cwagent/cwagent-serviceaccount.yaml
kubectl apply -f ${BASE}/cwagent/cwagent-daemonset.yaml
kubectl apply -f ${BASE}/fluent-bit/fluent-bit.yaml
```

---

## 7. Phase 4 — Deploy the Application

Argo CD handles this automatically after Phase 6b. To apply manually:

```bash
kubectl apply -f Kubernetes/namespace.yaml
kubectl apply -f Kubernetes/database/
kubectl apply -f Kubernetes/backend/
kubectl apply -f Kubernetes/frontend/
kubectl apply -f Kubernetes/ingress.yaml

# Wait for all pods
kubectl rollout status deployment/backend  -n blog-app --timeout=5m
kubectl rollout status deployment/frontend -n blog-app --timeout=5m
kubectl get pods -n blog-app
```

**Expected pods:**
```
NAME                        READY   STATUS
backend-xxxxx               1/1     Running
backend-xxxxx               1/1     Running
frontend-xxxxx              1/1     Running
frontend-xxxxx              1/1     Running
mysql-0                     1/1     Running
```

**Get the application URL:**
```bash
kubectl get ingress blog-app-ingress -n blog-app \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

---

## 8. Phase 5 — CI/CD Pipeline

The pipeline at `.github/workflows/devsecops.yml` runs automatically on every push to `main`.

### Pipeline stages

| # | Stage | Runs on |
|---|-------|---------|
| 1 | Code Quality & Tests | All pushes + PRs |
| 2 | Secret Scanning (Gitleaks) | All pushes + PRs |
| 3 | Dependency Audit (npm audit) | All pushes + PRs |
| 4 | Container Lint + Trivy Scan | All pushes + PRs |
| 5 | Build & Push to ECR | Push to main only |
| 6 | Update image tag in Git manifests | Push to main only |
| 7 | Verify EKS rollout | Push to main only |

### No secrets needed

Authentication is via **GitHub OIDC**. No `AWS_ACCESS_KEY_ID` or `AWS_SECRET_ACCESS_KEY` in GitHub secrets.

The only optional secret:

| Secret | Purpose |
|--------|---------|
| `GITOPS_TOKEN` | GitHub PAT with `contents:write` — allows CI to push manifest updates back. Falls back to `GITHUB_TOKEN` if not set. |

### How GitOps works

```
CI pushes new image tag to ECR
        │
CI updates image: line in Kubernetes/backend/backend-deployment.yml
        │
CI commits + pushes that change to main [the manifest now has the new SHA]
        │
Argo CD detects the diff → syncs to EKS → rolling update
```

---

## 9. Live URLs & Credentials

| Service | URL | Credentials |
|---------|-----|-------------|
| **Blog App** | http://k8s-blogapp-blogappi-7a85bee9fb-496479600.us-east-1.elb.amazonaws.com | — |
| **Grafana** | http://a6390d9a088804367b6dbf7d6724904d-671051682.us-east-1.elb.amazonaws.com | `admin` / `Admin@123` |
| **Prometheus** | http://a011a39a3318f425da392a08e0cf2f8b-196065776.us-east-1.elb.amazonaws.com:9090 | — |
| **Argo CD** | https://a41364aceacef4310b718680e68ec1ba-1929863741.us-east-1.elb.amazonaws.com | `admin` / `Q31DPa6mTiJwwyJB` |

> **Note:** ALB DNS names are stable but may change if the Ingress/Service is recreated.
> Always re-run `kubectl get ingress -n blog-app` and `kubectl get svc -n argocd` to get current values.

---

## 10. Validation Checklist

Run after every deployment:

```bash
# 1. Nodes healthy
kubectl get nodes

# 2. All blog-app pods Running
kubectl get pods -n blog-app

# 3. ArgoCD synced
kubectl get application blog-app -n argocd \
  -o jsonpath='{.status.health.status} {.status.sync.status}'
# Expected: Healthy Synced

# 4. Ingress has an address
kubectl get ingress -n blog-app

# 5. API responds
curl http://<ALB-DNS>/api/posts
# Expected: JSON array of posts

# 6. Frontend responds
curl -o /dev/null -w "%{http_code}" http://<ALB-DNS>/
# Expected: 200

# 7. Prometheus healthy
curl http://<PROMETHEUS-LB>:9090/-/healthy
# Expected: Prometheus Server is Healthy.

# 8. Grafana responds
curl -o /dev/null -w "%{http_code}" http://<GRAFANA-LB>/
# Expected: 200

# 9. ECR images exist
aws ecr list-images --repository-name prod/backend-blog-app \
  --region us-east-1 --query "imageIds[*].imageTag"

# 10. CloudWatch logs arriving (~5 min after first deploy)
aws logs describe-log-groups \
  --log-group-name-prefix /aws/containerinsights/blog-prod-eks \
  --region us-east-1
```

---

## 11. Troubleshooting

### Pod stuck in Pending — FailedScheduling

```bash
kubectl describe pod <pod-name> -n blog-app | grep -A5 "Events:"
```

| Message | Cause | Fix |
|---------|-------|-----|
| `volume node affinity conflict` | PVC EBS volume is in wrong AZ | Delete PVC + pod, recreate — PVC must be in same AZ as node |
| `Insufficient memory` | Node too small | Check node instance type — needs t3.medium minimum |
| `Too many pods` | Node at pod limit | Scale node group up |

### Pod in CrashLoopBackOff

```bash
kubectl logs <pod-name> -n blog-app --previous
kubectl describe pod <pod-name> -n blog-app
```

| Symptom | Cause | Fix |
|---------|-------|-----|
| `ECONNREFUSED 3306` | MySQL not ready yet | InitContainer waits — check mysql-0 is Running first |
| `Access denied for user` | Wrong DB credentials | Check `kubectl get secret mysql-secret -n blog-app -o yaml` |
| `OOMKilled` | Memory limit too low | Increase `resources.limits.memory` in deployment YAML |

### Argo CD OutOfSync

```bash
# See what differs
kubectl get application blog-app -n argocd -o yaml | grep -A10 "status:"

# Force sync
kubectl patch application blog-app -n argocd \
  --type merge -p '{"operation":{"sync":{}}}'
```

Common causes:
- CI pushed a new image tag but Argo CD hasn't polled yet (waits up to 3 min)
- Wrong `repoURL` in `argocd/application.yaml`
- Git repo is private and Argo CD has no credentials

### GitHub Actions OIDC failure

```
Error: Could not assume role with OIDC: Not authorized to perform sts:AssumeRoleWithWebIdentity
```

Steps:
1. Verify the trust policy sub claim matches exactly what GitHub sends:
   ```bash
   aws iam get-role --role-name github-actions-blog-app-role \
     --query "Role.AssumeRolePolicyDocument"
   ```
2. The sub must be `StringLike` with value ending in `:*`
3. Re-run `bash setup-iam-oidc.sh` if the role is missing or wrong

### EKS node group AMI error

```
InvalidParameterException: Requested AMI for this version X.XX is not supported
```

Fix: Update `cluster_version` in `Terraform/terraform.tfvars` to a supported version.
Check available AMIs:
```bash
aws ssm get-parameter \
  --name "/aws/service/eks/optimized-ami/1.31/amazon-linux-2/recommended/image_id" \
  --region us-east-1
```

---

## 12. Teardown

> ⚠️ **These commands delete all AWS resources and data permanently.**

```bash
# 1. Delete Kubernetes resources
kubectl delete -f Kubernetes/ -R
helm uninstall prometheus -n monitoring
kubectl delete namespace monitoring amazon-cloudwatch

# 2. Delete Argo CD
kubectl delete -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.12.0/manifests/install.yaml
kubectl delete namespace argocd

# 3. Destroy AWS infrastructure (EKS, VPC, ECR, IAM role)
cd Terraform
terraform destroy -auto-approve
```

Or trigger the GitHub Actions destroy workflow:
- Go to **Actions → Terraform Destroy → Run workflow**
- Type `destroy-infrastructure` in the confirmation box

---

*Last updated: matched to commit `de3e97da`*
