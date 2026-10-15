# Simple Blog App on AWS EKS – CI/CD & Monitoring

Full-stack blog (React + Node.js + MySQL-in-cluster) on Amazon EKS with:

- **GitHub Actions** (Jenkins removed) – Checkout, Build, Test, DevSecOps, Docker build, Push to ECR
- **GitHub OIDC** – passwordless AWS auth
- **Argo CD** – GitOps
- **Prometheus + Grafana** – dashboards & alerts
- **CloudWatch** – EKS logs
- **Terraform** in new `infra/` folder (original Terraform left untouched; RDS removed)

## Structure

```
backend/          Node.js API (env-based DB config)
frontend/         React SPA
k8s/              Manifests (namespace, mysql, backend, frontend)
infra/            New Terraform (modules, OIDC, no RDS)
argocd/           Argo CD Application
monitoring/       Prometheus values + custom alerts
.github/workflows CI/CD + DevSecOps
docs/             Deployment guide
```

## How to run

1. Edit `infra/terraform.tfvars` (github_org / github_repo)
2. `cd infra && terraform init && terraform apply`
3. Set GitHub secret `AWS_ROLE_ARN`
4. Follow `docs/DEPLOYMENT.md` for Argo CD + monitoring
5. Push code → pipeline + GitOps deploys the app

## DevSecOps stages
- Trivy filesystem + image scans
- Gitleaks secret scan
- npm audit
- Fail pipeline on CRITICAL/HIGH container vulns

## Completion Criteria
Application deployed on EKS through GitHub Actions + Argo CD and monitored with Prometheus/Grafana.
