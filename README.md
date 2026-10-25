# Simple Blog App — AWS EKS CI/CD & Monitoring

A full-stack blog application deployed on AWS EKS using GitHub Actions (CI), Argo CD (GitOps CD), Prometheus, Grafana, and AWS CloudWatch for monitoring.

This project was built as a DevOps internship assignment. It deliberately stays practical and readable, avoiding unnecessary complexity.

---

## Architecture

```
Developer → GitHub Push
      │
      ▼
GitHub Actions (CI)
  ├── Code checks (syntax + tests)
  ├── Secret scanning (Gitleaks)
  ├── Dependency audit (npm audit)
  ├── Dockerfile lint (hadolint)
  ├── Image vulnerability scan (Trivy)
  ├── Build & push images to ECR (OIDC)
  └── Update image tag in Kubernetes manifests (GitOps commit)
      │
      ▼
Argo CD (CD — GitOps)
  └── Detects manifest change → syncs to EKS cluster
      │
      ▼
AWS EKS Cluster (blog-prod-eks, us-east-1)
  └── Namespace: blog-app
      ├── frontend  (React + nginx, 2 replicas)
      ├── backend   (Node.js/Express, 2 replicas)
      └── mysql     (StatefulSet, 1 replica, EBS PVC)
          │
          ▼
AWS ALB Ingress (internet-facing)
  ├── /      → frontend-service:80
  └── /api   → backend-service:5003

Monitoring
  ├── Prometheus  (kube-prometheus-stack, namespace: monitoring)
  ├── Grafana     (dashboards: CPU, memory, pods, nodes, restarts)
  └── CloudWatch  (Container Insights: node/pod metrics + application logs)
```

---

## Repository Structure

```
.
├── .github/
│   └── workflows/
│       ├── devsecops.yml         # Main CI/CD pipeline (GitHub Actions)
│       ├── terraform-apply.yml   # Provision infrastructure with Terraform
│       └── terraform-destroy.yml # Destroy infrastructure (requires confirmation)
├── argocd/
│   ├── application.yaml          # Argo CD Application manifest
│   └── install-argocd.sh         # Argo CD installation script
├── backend/
│   ├── Dockerfile
│   ├── .dockerignore
│   ├── server.js                 # Express API (port 5003, /health endpoint)
│   ├── database.sql              # Schema reference
│   └── package.json
├── frontend/
│   ├── Dockerfile                # Multi-stage: build + nginx serve
│   ├── .dockerignore
│   ├── nginx.conf                # Nginx config (proxy /api → backend-service)
│   └── src/
├── Kubernetes/
│   ├── namespace.yaml            # blog-app namespace
│   ├── ingress.yaml              # AWS ALB Ingress
│   ├── backend/
│   │   ├── backend-deployment.yml
│   │   └── backend-service.yml
│   ├── frontend/
│   │   ├── frontend-deployment.yml
│   │   └── frontend-service.yml
│   └── database/
│       ├── configmap.yaml        # DB host/port + init.sql schema
│       ├── secret.yaml           # DB credentials (template — use real secrets in prod)
│       ├── statefulset.yaml
│       ├── service.yaml
│       └── pvc.yaml
├── Terraform/                    # EKS cluster, VPC, ECR, OIDC role
│   └── modules/
│       ├── vpc/
│       ├── eks/
│       ├── ecr/
│       └── github_oidc_role/
└── monitoring/
    ├── prometheus-rules.yaml     # PrometheusRule CRD (alerts)
    ├── grafana-dashboard.json    # Grafana dashboard (importable)
    ├── install-monitoring.sh     # Installs Prometheus + Grafana + CloudWatch
    ├── grafana-provisioning/
    │   ├── datasources/prometheus.yaml
    │   └── dashboards/dashboard-provider.yaml
    └── cloudwatch/
        ├── cloudwatch-agent-config.yaml
        └── fluentbit-config.yaml
```

---

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| AWS CLI | v2 | AWS access |
| kubectl | 1.30+ | Kubernetes control |
| helm | 3.x | Chart installs |
| Terraform | 1.12.x | Infrastructure provisioning |
| Docker | 24+ | Local image builds |
| Node.js | 20 | Local development |

---

## AWS Configuration

### Account values used in this project

| Value | Detail |
|-------|--------|
| AWS Account ID | `122384809512` |
| Region | `us-east-1` |
| EKS Cluster | `blog-prod-eks` |
| Backend ECR | `122384809512.dkr.ecr.us-east-1.amazonaws.com/prod/backend-blog-app` |
| Frontend ECR | `122384809512.dkr.ecr.us-east-1.amazonaws.com/prod/blog-app` |
| GitHub OIDC Role | `arn:aws:iam::122384809512:role/github-actions-blog-app-role` |

---

## Step 1: Provision Infrastructure with Terraform

The Terraform configuration creates:
- VPC with public and private subnets
- EKS cluster (`blog-prod-eks`, Kubernetes 1.30)
- Two ECR repositories
- GitHub OIDC IAM role

```bash
cd Terraform

# Configure your AWS credentials (one-time, for Terraform bootstrap)
aws configure

# Initialize providers and modules
terraform init

# Review the plan
terraform plan

# Apply (provisions EKS, takes ~15 minutes)
terraform apply
```

> The Terraform state is stored in S3 bucket `terraform-state-bucket-131` (us-east-1).
> Create that bucket before first apply if it doesn't exist:
> `aws s3 mb s3://terraform-state-bucket-131 --region us-east-1`

---

## Step 2: Configure GitHub Repository

### Secrets required

| Secret | Value | Notes |
|--------|-------|-------|
| `GITOPS_TOKEN` | GitHub PAT (contents:write) | Allows CI to push manifest updates back. Falls back to `GITHUB_TOKEN` if not set. |

> **No AWS credentials stored as secrets.** Authentication uses GitHub OIDC. The Terraform module creates the IAM role and OIDC provider automatically.

### GitHub OIDC Setup (what Terraform configures)

The IAM role `github-actions-blog-app-role` trusts:
```
token.actions.githubusercontent.com:sub = repo:pratikgayakwad07/DevsecOps-GitOps:*
```

Permissions granted:
- ECR: `GetAuthorizationToken`, `PutImage`, `InitiateLayerUpload`, etc. (push to the two ECR repos)
- EKS: `DescribeCluster`, `ListClusters`
- CloudWatch: `ReadOnlyAccess`

> Kubernetes RBAC access for `kubectl rollout status` in the verify step:
> After cluster creation, add the GitHub Actions role to `aws-auth` ConfigMap:
> ```
> kubectl edit configmap aws-auth -n kube-system
> ```
> Add the role ARN under `mapRoles` with `system:masters` group (or a scoped namespace role for production).

---

## Step 3: EKS Cluster Access

```bash
# Configure kubectl
aws eks update-kubeconfig --name blog-prod-eks --region us-east-1

# Verify nodes
kubectl get nodes

# Verify context
kubectl config current-context
```

---

## Step 4: Deploy the Application

### Option A — via Argo CD (recommended, GitOps)

```bash
# Install Argo CD and create the Application
bash argocd/install-argocd.sh

# Watch the sync
argocd app get blog-app
argocd app sync blog-app   # Only if auto-sync is off
```

### Option B — direct kubectl (for testing only)

```bash
kubectl apply -f Kubernetes/namespace.yaml
kubectl apply -f Kubernetes/database/
kubectl apply -f Kubernetes/backend/
kubectl apply -f Kubernetes/frontend/
kubectl apply -f Kubernetes/ingress.yaml
```

### Verify the deployment

```bash
kubectl get pods -n blog-app
kubectl get svc -n blog-app
kubectl get ingress -n blog-app
```

Expected output for pods:
```
NAME                        READY   STATUS    RESTARTS
backend-xxxxxxx-xxxxx       1/1     Running   0
backend-xxxxxxx-yyyyy       1/1     Running   0
frontend-xxxxxxx-xxxxx      1/1     Running   0
frontend-xxxxxxx-yyyyy      1/1     Running   0
mysql-0                     1/1     Running   0
```

### Access the application

Get the ALB DNS name:
```bash
kubectl get ingress blog-app-ingress -n blog-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

Open the URL in a browser. The blog homepage should appear.

---

## GitHub Actions CI Pipeline

The workflow at `.github/workflows/devsecops.yml` runs on push/PR to `main` or `master`.

| Job | Trigger | What it does |
|-----|---------|-------------|
| `code-checks` | always | Node.js syntax check + React tests |
| `secret-scanning` | always | Gitleaks scans full git history |
| `dependency-scan` | always | `npm audit --audit-level=critical` |
| `container-security` | always | hadolint + Trivy image scan |
| `build-and-push` | push to main only | OIDC → ECR login → docker build/push → update manifest → git commit |
| `verify-deployment` | push to main only | `kubectl rollout status` after Argo CD syncs |

### Image tagging

Images are tagged with the first 8 characters of the Git commit SHA:
```
122384809512.dkr.ecr.us-east-1.amazonaws.com/prod/backend-blog-app:a1b2c3d4
```

The CI job updates the `image:` line in the Kubernetes deployment YAML and pushes the commit back to main. Argo CD detects this change and syncs automatically.

---

## Argo CD GitOps Workflow

1. CI pushes updated deployment YAML to Git.
2. Argo CD polls the repo (default: every 3 minutes) or receives a webhook.
3. Argo CD detects the diff, syncs the cluster to match Git.
4. Kubernetes performs a rolling update.

### Access Argo CD UI

```bash
# Port-forward (no public exposure)
kubectl port-forward svc/argocd-server 8080:443 -n argocd

# Get initial admin password
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath='{.data.password}' | base64 -d && echo

# Open: https://localhost:8080
```

### Verify sync status

```bash
argocd app get blog-app
# Expected: Health: Healthy, Sync Status: Synced
```

---

## Prometheus Monitoring

### Install

```bash
bash monitoring/install-monitoring.sh
```

This runs `helm upgrade --install prometheus prometheus-community/kube-prometheus-stack` in the `monitoring` namespace, then applies the PrometheusRule.

### Access Prometheus

```bash
kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 -n monitoring
# Open: http://localhost:9090
```

### Useful PromQL queries

```promql
# Pod CPU usage (blog-app)
sum(rate(container_cpu_usage_seconds_total{namespace="blog-app",container!=""}[5m])) by (pod)

# Pod memory usage in MB (blog-app)
sum(container_memory_working_set_bytes{namespace="blog-app",container!=""}) by (pod) / (1024*1024)

# Pod restart rate
rate(kube_pod_container_status_restarts_total{namespace="blog-app"}[5m]) * 60

# Node CPU idle
avg by (node) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100
```

### Configured Alerts

| Alert | Condition | Severity |
|-------|-----------|----------|
| `PodCrashLooping` | restarts > 2/min for 2m | critical |
| `PodNotReady` | pod not ready for 5m | warning |
| `PodOOMKilled` | container killed OOM | critical |
| `HighPodCPUUsage` | pod CPU > 400m for 2m | warning |
| `HighNodeCPUUsage` | node CPU > 80% for 5m | warning |
| `HighPodMemoryUsage` | pod memory > 400Mi for 2m | warning |
| `HighNodeMemoryUsage` | node memory > 85% for 5m | warning |
| `NodeNotReady` | node NotReady for 2m | critical |
| `NodeDiskPressure` | DiskPressure condition | warning |

---

## Grafana Dashboards & Alerting

### Access Grafana

```bash
kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring
# Open: http://localhost:3000  (admin / admin by default)
```

### Import the dashboard

1. In Grafana: **Dashboards → Import**
2. Upload `monitoring/grafana-dashboard.json`
3. Select the Prometheus data source
4. Click **Import**

### Dashboard panels

| Panel | Metric |
|-------|--------|
| Running Pods | `kube_pod_status_phase{phase="Running"}` |
| Healthy Nodes | `kube_node_status_condition{condition="Ready"}` |
| Pod Restarts (1h) | `increase(kube_pod_container_status_restarts_total[1h])` |
| Node CPU % | `100 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100` |
| Node Memory % | `100 * (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)` |
| Pod CPU (cores) | `rate(container_cpu_usage_seconds_total[5m])` |
| Pod Memory (MB) | `container_memory_working_set_bytes` |
| Pod Status table | `kube_pod_status_phase` |
| Container Restarts | `kube_pod_container_status_restarts_total` |
| Node Conditions | `kube_node_status_condition` |

### Configure a Grafana alert

To add a Grafana-native alert (in addition to Prometheus alerts):
1. Open the "Pod CPU Utilization" panel.
2. Click **Edit → Alert → New alert rule**.
3. Condition: `WHEN last() OF query(A, 2m, now) IS ABOVE 0.4`
4. Notifications: configure a contact point (email, Slack, etc.) under **Alerting → Contact Points**.

---

## AWS CloudWatch Monitoring

The `install-monitoring.sh` script installs:
- **CloudWatch Agent DaemonSet** — collects Container Insights metrics (CPU, memory, disk, network per pod/node)
- **Fluent Bit DaemonSet** — ships pod logs to CloudWatch Logs

### Log Groups created automatically

| Log Group | Contents |
|-----------|----------|
| `/aws/containerinsights/blog-prod-eks/application` | Pod stdout/stderr |
| `/aws/containerinsights/blog-prod-eks/dataplane` | Kubelet and Docker system logs |
| `/aws/containerinsights/blog-prod-eks/host` | Node-level OS logs |

### Verify CloudWatch

```bash
# Check agent pods
kubectl get pods -n amazon-cloudwatch

# Verify log groups exist (after ~5 minutes)
aws logs describe-log-groups \
  --log-group-name-prefix /aws/containerinsights/blog-prod-eks \
  --region us-east-1

# Tail application logs
aws logs tail /aws/containerinsights/blog-prod-eks/application --follow

# View EKS control-plane logs (enable in the AWS console or CLI)
aws eks update-cluster-config \
  --name blog-prod-eks \
  --logging '{"clusterLogging":[{"types":["api","audit","authenticator","controllerManager","scheduler"],"enabled":true}]}' \
  --region us-east-1

# Verify EKS control-plane log group
aws logs describe-log-groups --log-group-name-prefix /aws/eks/blog-prod-eks/cluster
```

### IAM requirement for Container Insights

The EKS node IAM role must have `CloudWatchAgentServerPolicy` attached:
```bash
aws iam attach-role-policy \
  --role-name <EKS_NODE_ROLE_NAME> \
  --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy
```

---

## Troubleshooting

### A. Pod in CrashLoopBackOff

**Detect:**
```bash
kubectl get pods -n blog-app
# Look for: STATUS = CrashLoopBackOff or Error
```

**Diagnose:**
```bash
# Current logs
kubectl logs <pod-name> -n blog-app

# Previous container logs (most useful after a crash)
kubectl logs <pod-name> -n blog-app --previous

# Events and conditions
kubectl describe pod <pod-name> -n blog-app
```

**Common causes and fixes:**

| Cause | Fix |
|-------|-----|
| Wrong DB credentials | Check Secret values: `kubectl get secret mysql-secret -n blog-app -o yaml` |
| MySQL not ready when backend starts | InitContainer `wait-for-mysql` handles this; check initContainer logs |
| OOMKilled | Increase `resources.limits.memory` in deployment YAML |
| Bad image | Check image tag in deployment: `kubectl describe pod <pod-name>` |
| Config missing | Verify ConfigMap: `kubectl get configmap mysql-config -n blog-app -o yaml` |

---

### B. Argo CD Application OutOfSync

**Detect:**
```bash
argocd app get blog-app
# Look for: Sync Status: OutOfSync
```

**Diagnose:**
```bash
# Show what differs between Git and cluster
argocd app diff blog-app

# Check Argo CD logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

**Common causes and fixes:**

| Cause | Fix |
|-------|-----|
| Wrong `repoURL` | Check `argocd/application.yaml` → `spec.source.repoURL` |
| Wrong `path` | Verify `spec.source.path` matches the `Kubernetes/` folder |
| Git credentials missing | `kubectl get secret -n argocd` — check `argocd-repo-creds` |
| Image tag mismatch | Re-run CI pipeline to push new image and update manifest |
| Manual `kubectl apply` bypassed Git | Argo CD self-heal will revert it; fix in Git instead |

**Sync manually:**
```bash
argocd app sync blog-app
```

---

### C. GitHub Actions Pipeline Failure

| Failure | Cause | Fix |
|---------|-------|-----|
| Checkout fails | Repo permissions | Check `contents: read` permission in workflow |
| `npm ci` fails | Dependency conflict or missing lock file | Run `npm install` locally, commit updated `package-lock.json` |
| Tests fail | Actual test failure | Read test output; `npm test -- --watchAll=false --verbose` locally |
| Docker build fails | Syntax error in Dockerfile | Run `docker build` locally; check hadolint output |
| ECR login fails | OIDC trust policy mismatch | Verify `repository_pattern` in Terraform matches the exact repo path |
| OIDC `AccessDenied` | Wrong role ARN or audience | Confirm `ROLE_ARN` env var; check IAM role trust policy `sub` condition |
| `docker push` denied | ECR push policy missing | Re-apply Terraform — the `ecr_push` IAM policy was added |
| Git push fails (manifest update) | No write permission | Set `GITOPS_TOKEN` secret with `contents:write` scope |

**Verify OIDC from GitHub:**
```bash
# Check what identity the workflow is using
aws sts get-caller-identity
# Should show: arn:aws:sts::122384809512:assumed-role/github-actions-blog-app-role/...
```

---

### D. Application / Service Connectivity Issues

**Step 1 — Check pods are running:**
```bash
kubectl get pods -n blog-app -o wide
kubectl describe pod <pod-name> -n blog-app
```

**Step 2 — Check service selectors match pod labels:**
```bash
kubectl get svc -n blog-app
kubectl describe svc backend-service -n blog-app
# Endpoints section must list pod IPs — empty endpoints = selector mismatch
kubectl get endpoints backend-service -n blog-app
```

**Step 3 — Test in-cluster DNS:**
```bash
kubectl run debug --image=busybox:1.36 --restart=Never --rm -it -- \
  wget -O- http://backend-service.blog-app.svc.cluster.local:5003/health
```

**Step 4 — Check the ingress:**
```bash
kubectl describe ingress blog-app-ingress -n blog-app
# Look for: Address = <ALB DNS>
# Verify ALB target group health in AWS Console
```

**Step 5 — Check health probes:**
```bash
# If readiness probe fails, pod won't get traffic
kubectl describe pod <pod-name> -n blog-app | grep -A 10 "Readiness"
```

**Step 6 — Check AWS Load Balancer Controller:**
```bash
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

> Note: The ALB Ingress requires the AWS Load Balancer Controller to be installed on the cluster.
> Install it with:
> ```bash
> helm repo add eks https://aws.github.io/eks-charts
> helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
>   -n kube-system \
>   --set clusterName=blog-prod-eks \
>   --set serviceAccount.create=true
> ```

---

## Cleanup

> ⚠️ These commands destroy AWS resources and **cannot be undone**.

```bash
# Delete application resources
kubectl delete -f Kubernetes/ -R

# Uninstall monitoring
helm uninstall prometheus -n monitoring
kubectl delete namespace monitoring amazon-cloudwatch

# Uninstall Argo CD
kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.12.0/manifests/install.yaml
kubectl delete namespace argocd

# Destroy all AWS infrastructure (EKS, VPC, ECR, IAM role)
# REQUIRES manual confirmation: type 'destroy-infrastructure' in the workflow input
# OR run locally:
cd Terraform
terraform destroy
```

---

## Quick Validation Checklist

- [ ] `aws sts get-caller-identity` returns the expected account
- [ ] `kubectl get nodes` shows Ready nodes
- [ ] `kubectl get pods -n blog-app` shows all pods Running
- [ ] `kubectl get ingress -n blog-app` shows an ALB address
- [ ] Blog app accessible at `http://<ALB-DNS>/`
- [ ] API accessible at `http://<ALB-DNS>/api/posts`
- [ ] GitHub Actions workflow passes on push to main
- [ ] ECR repositories contain the new image tag
- [ ] Argo CD shows Synced + Healthy
- [ ] Prometheus targets healthy at `http://localhost:9090/targets`
- [ ] Grafana dashboard shows metrics
- [ ] CloudWatch log groups contain logs

---

*Built by a DevOps Intern as part of an AWS EKS CI/CD and Monitoring assignment.*
