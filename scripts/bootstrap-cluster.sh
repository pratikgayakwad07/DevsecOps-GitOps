#!/usr/bin/env bash
# =============================================================================
# scripts/bootstrap-cluster.sh
# Automated Post-Provisioning for Amazon EKS:
# - Verifies cluster authentication
# - Ensures gp3 StorageClass (AWS EBS CSI Driver)
# - Installs AWS Load Balancer Controller
# - Installs Argo CD & applies GitOps Application
# - Installs Prometheus & Grafana (kube-prometheus-stack)
# =============================================================================

set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-blog-prod-eks}"
AWS_REGION="${AWS_REGION:-us-east-1}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "============================================================"
echo " Starting Full EKS Bootstrap for: ${CLUSTER_NAME} (${AWS_REGION})"
echo "============================================================"

# -----------------------------------------------------------------------------
# 1. Update Kubeconfig & Verify Access
# -----------------------------------------------------------------------------
echo "==> [1/5] Updating Kubeconfig..."
aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${AWS_REGION}"
kubectl get nodes -o wide

# -----------------------------------------------------------------------------
# 2. StorageClass (gp3)
# -----------------------------------------------------------------------------
echo "==> [2/5] Configuring StorageClass (gp3)..."
if [ -f "${REPO_ROOT}/Kubernetes/storageclass.yaml" ]; then
  kubectl apply -f "${REPO_ROOT}/Kubernetes/storageclass.yaml"
else
  cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
parameters:
  type: gp3
  fsType: ext4
EOF
fi

# -----------------------------------------------------------------------------
# 3. AWS Load Balancer Controller
# -----------------------------------------------------------------------------
echo "==> [3/5] Installing / Upgrading AWS Load Balancer Controller..."
helm repo add eks https://aws.github.io/eks-charts || true
helm repo update eks

helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="${CLUSTER_NAME}" \
  --set serviceAccount.create=true \
  --set region="${AWS_REGION}" \
  --wait --timeout=5m || echo "Warning: LBC helm install completed with warnings."

# -----------------------------------------------------------------------------
# 4. Argo CD & GitOps Application
# -----------------------------------------------------------------------------
echo "==> [4/5] Installing Argo CD & Syncing GitOps Application..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

helm repo add argo https://argoproj.github.io/argo-helm || true
helm repo update argo

helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --set server.service.type="LoadBalancer" \
  --set configs.params."server\.insecure"=true \
  --wait --timeout=10m

# Apply Argo CD Application
if [ -f "${REPO_ROOT}/argocd/application.yaml" ]; then
  echo "==> Applying Argo CD Application manifest..."
  kubectl apply -f "${REPO_ROOT}/argocd/application.yaml"
fi

# -----------------------------------------------------------------------------
# 5. Monitoring (Prometheus + Grafana)
# -----------------------------------------------------------------------------
echo "==> [5/5] Installing Prometheus & Grafana Monitoring..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
helm repo update prometheus-community

helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.adminPassword="Admin@123" \
  --set grafana.service.type="LoadBalancer" \
  --set prometheus.service.type="ClusterIP" \
  --set alertmanager.service.type="ClusterIP" \
  --set prometheus.prometheusSpec.retention="15d" \
  --wait --timeout=10m

if [ -f "${REPO_ROOT}/monitoring/prometheus-rules.yaml" ]; then
  kubectl apply -f "${REPO_ROOT}/monitoring/prometheus-rules.yaml"
fi

# -----------------------------------------------------------------------------
# Verification & Credentials
# -----------------------------------------------------------------------------
echo ""
echo "============================================================"
echo " Full Bootstrap Complete! Current Cluster Status:"
echo "============================================================"
kubectl get pods -A | grep -E "argocd|monitoring|blog-app|kube-system" || true

echo ""
echo "--- Argo CD Details ---"
echo "URL: $(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo 'Pending LoadBalancer DNS')"
echo "Username: admin"
echo "Password retrieved via:"
echo "  kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d"

echo ""
echo "--- Grafana Details ---"
echo "URL: $(kubectl get svc prometheus-grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo 'Pending LoadBalancer DNS')"
echo "Username: admin"
echo "Password: Admin@123"
echo "============================================================"

