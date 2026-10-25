#!/usr/bin/env bash
# install-argocd.sh
# Installs Argo CD on the EKS cluster and deploys the blog-app Application.
#
# Usage: bash argocd/install-argocd.sh
# Requirements: kubectl, aws cli configured for the target cluster

set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-blog-prod-eks}"
AWS_REGION="${AWS_REGION:-us-east-1}"
ARGOCD_NS="argocd"
ARGOCD_VERSION="v2.12.0"

echo "==> Updating kubeconfig for cluster: ${CLUSTER_NAME}"
aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${AWS_REGION}"

echo "==> Creating argocd namespace"
kubectl create namespace "${ARGOCD_NS}" --dry-run=client -o yaml | kubectl apply -f -

echo "==> Installing Argo CD ${ARGOCD_VERSION}"
kubectl apply -n "${ARGOCD_NS}" \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"

echo "==> Waiting for Argo CD pods to be ready (up to 5 minutes)"
kubectl wait --for=condition=available deployment/argocd-server \
  -n "${ARGOCD_NS}" --timeout=5m

echo "==> Applying blog-app Application manifest"
kubectl apply -f "$(dirname "$0")/application.yaml"

echo ""
echo "==> Argo CD installed and blog-app Application created."
echo ""
echo "  Get initial admin password:"
echo "    kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d && echo"
echo ""
echo "  Access Argo CD UI (port-forward):"
echo "    kubectl port-forward svc/argocd-server 8080:443 -n argocd"
echo "    Open: https://localhost:8080  (admin / <password from above>)"
echo ""
echo "  Install argocd CLI and login:"
echo "    argocd login localhost:8080 --insecure"
echo ""
echo "  Check application sync status:"
echo "    argocd app get blog-app"
echo "    argocd app sync blog-app"
echo ""
