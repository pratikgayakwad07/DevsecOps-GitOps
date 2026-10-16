# 🚀 Simple Blog App on AWS EKS  
### DevOps Intern / Trainee Project

> This project was built as part of my DevOps internship learning journey.  
> Goal: Understand how a real application goes from code → security checks → containers → Kubernetes on AWS.

---

## 📌 What is this project?

A simple full-stack **Blog Application** deployed on **Amazon EKS** with a complete **DevSecOps** pipeline.

| Layer          | Technology              | Why I used it                     |
|----------------|-------------------------|-----------------------------------|
| Frontend       | React + Vite + Nginx    | Modern & fast UI                  |
| Backend        | Node.js + Express       | Easy REST API                     |
| Database       | MySQL                   | Relational data for posts         |
| Containers     | Docker                  | Package the app                   |
| Orchestration  | Amazon EKS              | Managed Kubernetes                |
| Infrastructure | Terraform               | Everything as code                |
| CI/CD          | GitHub Actions          | No Jenkins needed                 |
| GitOps         | Argo CD                 | Automatic deployment from Git     |
| Security       | Trivy, Gitleaks, npm audit | Shift-left security            |
| Monitoring     | Prometheus + Grafana    | See what is happening             |

---

## 🏗️ High-level Architecture

```
Developer pushes code
        ↓
GitHub Actions (CI)
  • Secret scan (Gitleaks)
  • Dependency audit
  • Trivy filesystem + image scan
  • Build Docker images
  • Push to Amazon ECR
        ↓
Argo CD (GitOps)
  • Watches the Git repo
  • Deploys new image tags to EKS
        ↓
Amazon EKS Cluster
  ├── Frontend  (React)
  ├── Backend   (Node.js)
  └── MySQL     (StatefulSet)
        ↓
Prometheus + Grafana (Monitoring)
```

---

## 🛠️ Tools I learned in this project

- Git & GitHub
- Docker (multi-stage builds, non-root user)
- Terraform (modules, variables, outputs)
- Kubernetes (Deployments, Services, StatefulSet, PVC, ConfigMap, Secret)
- Amazon EKS, ECR, VPC, IAM (OIDC)
- GitHub Actions (workflows, secrets, OIDC)
- Argo CD (GitOps)
- Trivy & Gitleaks (security scanning)
- Prometheus & Grafana (basic monitoring)

---

## 📋 Prerequisites

Before starting you need:

1. An AWS account
2. AWS CLI configured (`aws configure`)
3. `kubectl`, `terraform` installed
4. A GitHub account
5. Basic knowledge of Linux commands

> 💰 **Cost Warning**  
> EKS is **not free**. With 2 small nodes it can cost $3–6 per day.  
> Always run `terraform destroy` when you finish practicing!

---

## 🚦 Step-by-step Guide (for beginners)

### Step 1 – Clone / Fork the repository

```bash
git clone https://github.com/YOUR_USERNAME/blog-app-eks-devsecops.git
cd blog-app-eks-devsecops
```

### Step 2 – Update Terraform variables

Open the file `infra/terraform.tfvars` and change:

```hcl
github_org  = "YOUR_GITHUB_USERNAME"   # ← put your GitHub username here
github_repo = "blog-app-eks-devsecops"
```

### Step 3 – Create the infrastructure

```bash
cd infra
terraform init
terraform plan
terraform apply
```

Type `yes` when asked.  
This will create VPC, EKS cluster, ECR repositories and the GitHub OIDC role.  
It usually takes **12–18 minutes**.

### Step 4 – Connect kubectl to the cluster

```bash
aws eks update-kubeconfig --name blog-prod-eks --region us-east-1
kubectl get nodes
```

You should see 2 nodes in Ready state.

### Step 5 – Install Argo CD

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Get the admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

### Step 6 – Set GitHub Secrets

Go to your GitHub repository → **Settings → Secrets and variables → Actions**

Add these secrets:

| Secret Name             | Value                                      |
|-------------------------|--------------------------------------------|
| `AWS_ACCESS_KEY_ID`     | Your AWS access key                        |
| `AWS_SECRET_ACCESS_KEY` | Your AWS secret key                        |
| `AWS_REGION`             | `us-east-1`                                |
| `AWS_ROLE_ARN`           | Output from Terraform (see below)          |

Get the role ARN:

```bash
cd infra
terraform output github_actions_role_arn
```

### Step 7 – Replace ACCOUNT_ID

Find your AWS account ID:

```bash
aws sts get-caller-identity --query Account --output text
```

Replace the word `ACCOUNT_ID` in these files with your real account ID:

- `K8's/frontend/frontend-deployment.yml`
- `K8's/backend/backend-deployment.yml`
- `K8's/kustomization.yaml`

### Step 8 – Push code and watch the magic

```bash
git add .
git commit -m "first deploy by intern"
git push origin main
```

Go to the **Actions** tab in GitHub.  
You will see the pipeline running:

1. Secret scanning
2. Dependency audit
3. Trivy scan
4. Build & push Docker images
5. Update image tags
6. Argo CD deploys everything

### Step 9 – Open the application

```bash
kubectl get svc frontend-service -n blog-app
```

Copy the `EXTERNAL-IP` (or hostname) and open it in your browser.  
You should see the Blog App!

---

## 📊 Monitoring (Prometheus + Grafana)

```bash
kubectl apply -k "K8's/monitoring"
kubectl get svc grafana -n monitoring
```

Open the Grafana LoadBalancer URL.

- Username: `admin`
- Password: `admin123`  ← change this later!

---

## 🧹 How to destroy everything (important!)

```bash
cd infra
terraform destroy
```

Type `yes`.  
This deletes the EKS cluster, VPC, load balancers etc. so you stop getting charged.

---

## 📁 Project Structure (easy to understand)

```
blog-app-eks-devsecops/
├── .github/workflows/     ← CI/CD pipelines
│   ├── DevSecOps.yml      ← Main pipeline (scan + build + deploy)
│   ├── terraform.yml      ← Creates AWS infrastructure
│   └── destroy.yml        ← Safely destroys everything
├── backend/               ← Node.js API code
├── frontend/              ← React frontend code
├── infra/                 ← Terraform code (VPC, EKS, ECR)
├── K8's/                  ← Kubernetes manifests
│   ├── frontend/
│   ├── backend/
│   ├── database/
│   └── monitoring/        ← Prometheus + Grafana
├── argocd/                ← Argo CD Application
└── README.md              ← This file
```

---

## 🔒 Security features I implemented

- ✅ Non-root containers
- ✅ Read-only root filesystem
- ✅ Dropped all Linux capabilities
- ✅ Multi-stage Docker builds
- ✅ Gitleaks (secret scanning)
- ✅ Trivy (vulnerability scanning)
- ✅ npm audit
- ✅ GitHub OIDC (no long-lived keys in CI)

---

## 💡 What I learned as a trainee

1. How to write Terraform modules
2. Difference between Deployment and StatefulSet
3. Why we use GitOps (Argo CD) instead of kubectl apply from CI
4. How to scan Docker images before pushing them
5. How IAM OIDC works with GitHub Actions
6. How to keep AWS cost under control

---

## 🐛 Common problems I faced (and solutions)

| Problem                        | Solution                                      |
|--------------------------------|-----------------------------------------------|
| Terraform fails on OIDC        | The OIDC provider already exists → import it  |
| Images not pulling             | Check ACCOUNT_ID and ECR permissions          |
| MySQL pod Pending              | Wait for EBS CSI driver (2-3 min)             |
| Argo CD not syncing            | Check repo URL in `argocd/application.yaml`   |
| High AWS bill                  | Always run `terraform destroy` after practice |

---

## 🎯 Next learning goals

- [ ] Add HTTPS with AWS Certificate Manager + ALB Ingress
- [ ] Move secrets to AWS Secrets Manager
- [ ] Add Kubernetes NetworkPolicies
- [ ] Create better Grafana dashboards
- [ ] Add Horizontal Pod Autoscaler (HPA)

---

**Built with ❤️ by a DevOps Intern**  
Happy Learning! Always destroy the cluster when you are done.
