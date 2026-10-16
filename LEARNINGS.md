# 📝 My Learning Notes – DevOps Internship

This file contains things I learned while building this project.
I wrote it so that future me (or other trainees) can understand the "why".

---

## 1. Why Terraform?

Before Terraform I used to create resources from the AWS Console.
That is fine for learning, but:
- You cannot repeat the same environment easily
- You forget what you created
- It is hard to destroy everything cleanly

With Terraform everything is code → easy to create, change and destroy.

**Key commands I use every day:**
```bash
terraform init      # download providers
terraform plan      # see what will change
terraform apply     # create/update
terraform destroy   # delete everything
```

---

## 2. Why GitHub Actions instead of Jenkins?

Jenkins needs a server that is always running (cost + maintenance).
GitHub Actions runs only when you push code → cheaper and simpler for small projects.

I also learned **OIDC**:
- No need to store long-lived AWS Access Keys in GitHub
- GitHub temporarily assumes an IAM role
- More secure

---

## 3. Why Argo CD (GitOps)?

Old way:
```
CI builds image → CI runs kubectl apply
```

Problems:
- CI needs Kubernetes credentials
- Hard to know what is currently running
- Manual changes in cluster get lost

GitOps way (Argo CD):
```
CI only updates the Git repo (image tag)
Argo CD watches Git and makes the cluster match Git
```

This is cleaner and more secure.

---

## 4. Docker security practices I applied

| Practice                    | Why it matters                          |
|-----------------------------|-----------------------------------------|
| Multi-stage build           | Smaller final image                     |
| Non-root user               | Less damage if container is compromised |
| Read-only root filesystem   | Attacker cannot write files             |
| Drop all capabilities       | Remove unnecessary Linux privileges     |
| Distroless / slim base      | Fewer packages = fewer vulnerabilities  |

---

## 5. Kubernetes concepts I finally understood

- **Deployment** → for stateless apps (frontend, backend)
- **StatefulSet** → for stateful apps (MySQL) – keeps the same volume
- **Service** → stable network name + load balancing
- **ConfigMap** → non-sensitive configuration
- **Secret** → sensitive data (password) – still base64, not encrypted by default
- **PVC + StorageClass** → persistent disk for MySQL

---

## 6. Security scanning tools

| Tool       | What it does                          |
|------------|---------------------------------------|
| Gitleaks   | Finds secrets accidentally committed  |
| npm audit  | Finds vulnerable npm packages         |
| Trivy      | Scans files and Docker images for CVEs|

I configured the pipeline to **fail** if HIGH or CRITICAL vulnerabilities are found.

---

## 7. Cost control tips I learned the hard way

- Use `t3.small` or `t3.medium` only
- Keep desired nodes = 2 (or even 1 for testing)
- Always destroy the cluster after practice
- NAT Gateway is expensive – that is why private subnets cost money
- Load Balancers also cost money while they exist

---

## 8. Useful commands I keep in my notes

```bash
# Cluster
kubectl get nodes
kubectl get pods -A
kubectl get svc -n blog-app

# Logs
kubectl logs -n blog-app -l app=backend --tail=100

# Describe problem
kubectl describe pod <pod-name> -n blog-app

# Argo CD
kubectl get applications -n argocd

# Terraform
terraform output
terraform state list
```

---

## 9. Mistakes I made (so you don't)

1. Forgot to replace ACCOUNT_ID → images could not be pulled
2. Left cluster running overnight → unexpected bill
3. Used `latest` tag only → hard to rollback
4. Put real passwords in Git (never do this!)

---

**Remember**: The goal of an internship project is not perfection.  
The goal is to **understand** every piece and be able to explain it.
