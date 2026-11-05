# -----------------------------------------------------------------------------
# EKS Addons, Ingress, ArgoCD & Monitoring Automation (Option 1)
# -----------------------------------------------------------------------------

# 1. AWS EBS StorageClass (gp3)
resource "kubernetes_storage_class_v1" "gp3" {
  count = var.enable_gitops_addons ? 1 : 0

  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    type   = "gp3"
    fsType = "ext4"
  }

  depends_on = [module.eks]
}

# 2. Argo CD via Helm Release
resource "helm_release" "argocd" {
  count            = var.enable_gitops_addons ? 1 : 0
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "7.7.0"
  namespace        = "argocd"
  create_namespace = true

  set {
    name  = "server.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "configs.params.server\\.insecure"
    value = "true"
  }

  depends_on = [module.eks]
}

# 3. Argo CD Application for GitOps Blog App (direct kubernetes_manifest - avoids argocd-apps chart bug)
resource "kubernetes_manifest" "argocd_application" {
  count = var.enable_gitops_addons ? 1 : 0

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name       = "blog-app"
      namespace  = "argocd"
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = "https://github.com/pratikgayakwad07/DevsecOps-GitOps.git"
        targetRevision = "HEAD"
        path           = "Kubernetes"
        directory = {
          recurse = true
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "blog-app"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=true",
          "PrunePropagationPolicy=foreground",
          "RespectIgnoreDifferences=true"
        ]
        retry = {
          limit = 5
          backoff = {
            duration    = "5s"
            factor      = 2
            maxDuration = "3m"
          }
        }
      }
    }
  }

  depends_on = [helm_release.argocd]
}

# 4. Prometheus + Grafana via Helm (kube-prometheus-stack)
resource "helm_release" "monitoring" {
  count            = var.enable_gitops_addons ? 1 : 0
  name             = "prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = "65.5.0"
  namespace        = "monitoring"
  create_namespace = true

  set {
    name  = "grafana.adminPassword"
    value = "Admin@123"
  }

  set {
    name  = "grafana.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "prometheus.service.type"
    value = "ClusterIP"
  }

  set {
    name  = "prometheus.prometheusSpec.retention"
    value = "15d"
  }

  depends_on = [module.eks]
}
