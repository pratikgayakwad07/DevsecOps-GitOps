<#
.SYNOPSIS
  Automated Post-Provisioning script for Amazon EKS on Windows PowerShell.
#>
param(
    [string]$ClusterName = "blog-prod-eks",
    [string]$AwsRegion = "us-east-1"
)

$ErrorActionPreference = "Stop"
$kubectl = "$env:USERPROFILE\kubectl.exe"
$repoRoot = Split-Path -Parent $PSScriptRoot

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Starting Full EKS Bootstrap for: $ClusterName ($AwsRegion)" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# 1. Update Kubeconfig
Write-Host "==> [1/5] Updating Kubeconfig..." -ForegroundColor Yellow
aws eks update-kubeconfig --name $ClusterName --region $AwsRegion
& $kubectl get nodes -o wide

# 2. StorageClass (gp3)
Write-Host "==> [2/5] Configuring StorageClass (gp3)..." -ForegroundColor Yellow
$scPath = Join-Path $repoRoot "Kubernetes\storageclass.yaml"
if (Test-Path $scPath) {
    & $kubectl apply -f $scPath
}

# 3. AWS Load Balancer Controller
Write-Host "==> [3/5] Installing AWS Load Balancer Controller..." -ForegroundColor Yellow
helm repo add eks https://aws.github.io/eks-charts
helm repo update eks
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller `
  -n kube-system `
  --set clusterName=$ClusterName `
  --set serviceAccount.create=true `
  --set region=$AwsRegion `
  --wait --timeout=5m

# 4. Argo CD
Write-Host "==> [4/5] Installing Argo CD & GitOps Application..." -ForegroundColor Yellow
& $kubectl create namespace argocd --dry-run=client -o yaml | & $kubectl apply -f -
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update argo
helm upgrade --install argocd argo/argo-cd `
  --namespace argocd `
  --set server.service.type="LoadBalancer" `
  --set configs.params."server\.insecure"=true `
  --wait --timeout=10m

$argoAppPath = Join-Path $repoRoot "argocd\application.yaml"
if (Test-Path $argoAppPath) {
    Write-Host "==> Applying Argo CD Application manifest..." -ForegroundColor Yellow
    & $kubectl apply -f $argoAppPath
}

# 5. Monitoring
Write-Host "==> [5/5] Installing Prometheus & Grafana Monitoring..." -ForegroundColor Yellow
& $kubectl create namespace monitoring --dry-run=client -o yaml | & $kubectl apply -f -
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update prometheus-community
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack `
  --namespace monitoring `
  --set grafana.adminPassword="Admin@123" `
  --set grafana.service.type="LoadBalancer" `
  --set prometheus.service.type="ClusterIP" `
  --set alertmanager.service.type="ClusterIP" `
  --set prometheus.prometheusSpec.retention="15d" `
  --wait --timeout=10m

Write-Host "============================================================" -ForegroundColor Green
Write-Host " Full Bootstrap Complete!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
