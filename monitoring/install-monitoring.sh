#!/usr/bin/env bash
# install-monitoring.sh
# Installs kube-prometheus-stack (Prometheus + Grafana + Alertmanager)
# and configures CloudWatch Container Insights on the EKS cluster.
#
# Usage: bash monitoring/install-monitoring.sh
# Requirements: helm, kubectl, aws cli configured for the target cluster

set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-blog-prod-eks}"
AWS_REGION="${AWS_REGION:-us-east-1}"
MONITORING_NS="monitoring"
CLOUDWATCH_NS="amazon-cloudwatch"

echo "==> Updating kubeconfig for cluster: ${CLUSTER_NAME}"
aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${AWS_REGION}"

echo "==> Verifying cluster access"
kubectl get nodes

# -----------------------------------------------------------------------
# 1. Install kube-prometheus-stack (Prometheus + Grafana + Alertmanager)
# -----------------------------------------------------------------------
echo "==> Adding prometheus-community Helm repo"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

echo "==> Creating monitoring namespace"
kubectl create namespace "${MONITORING_NS}" --dry-run=client -o yaml | kubectl apply -f -

echo "==> Installing kube-prometheus-stack"
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace "${MONITORING_NS}" \
  --set grafana.adminPassword="admin" \
  --set grafana.service.type="ClusterIP" \
  --set prometheus.service.type="ClusterIP" \
  --set alertmanager.service.type="ClusterIP" \
  --set prometheus.prometheusSpec.retention="15d" \
  --set grafana.sidecar.dashboards.enabled=true \
  --wait --timeout=10m

echo "==> Applying Prometheus alert rules"
kubectl apply -f "$(dirname "$0")/prometheus-rules.yaml"

echo "==> Prometheus and Grafana installed."
echo ""
echo "  Access Grafana:"
echo "    kubectl port-forward svc/prometheus-grafana 3000:80 -n ${MONITORING_NS}"
echo "    Open: http://localhost:3000  (admin / admin)"
echo ""
echo "  Access Prometheus:"
echo "    kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 -n ${MONITORING_NS}"
echo "    Open: http://localhost:9090"
echo ""

# -----------------------------------------------------------------------
# 2. Install CloudWatch Container Insights
# -----------------------------------------------------------------------
echo "==> Setting up CloudWatch Container Insights"

echo "==> Creating amazon-cloudwatch namespace"
kubectl create namespace "${CLOUDWATCH_NS}" --dry-run=client -o yaml | kubectl apply -f -

echo "==> Applying CloudWatch agent config"
kubectl apply -f "$(dirname "$0")/cloudwatch/cloudwatch-agent-config.yaml"

BASE_URL="https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring"

echo "==> Applying CloudWatch agent service account"
kubectl apply -f "${BASE_URL}/cwagent/cwagent-serviceaccount.yaml"

echo "==> Applying CloudWatch agent DaemonSet"
kubectl apply -f "${BASE_URL}/cwagent/cwagent-daemonset.yaml"

echo "==> Applying Fluent Bit config"
kubectl apply -f "$(dirname "$0")/cloudwatch/fluentbit-config.yaml"

echo "==> Applying Fluent Bit DaemonSet"
kubectl apply -f "${BASE_URL}/fluent-bit/fluent-bit.yaml"

echo ""
echo "==> CloudWatch Container Insights installed."
echo "    Log groups (created automatically after first logs arrive):"
echo "      /aws/containerinsights/${CLUSTER_NAME}/application"
echo "      /aws/containerinsights/${CLUSTER_NAME}/dataplane"
echo "      /aws/containerinsights/${CLUSTER_NAME}/host"
echo ""
echo "  Verify in AWS Console: CloudWatch > Log groups"
echo "  Or: aws logs describe-log-groups --log-group-name-prefix /aws/containerinsights/${CLUSTER_NAME}"
echo ""
echo "==> Done!"
