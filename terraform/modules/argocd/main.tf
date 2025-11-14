# ArgoCD Module
# Installs ArgoCD for GitOps continuous deployment

data "aws_caller_identity" "current" {}

# Create namespace
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.namespace
    labels = {
      name = var.namespace
    }
  }
}

# Install ArgoCD via Helm
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.chart_version
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  # High Availability configuration
  values = [
    yamlencode({
      global = {
        domain = "argocd.${var.domain}"
      }

      # Controller (manages application state)
      controller = {
        replicas = var.enable_ha ? 2 : 1
        resources = {
          limits = {
            cpu    = "1000m"
            memory = "2Gi"
          }
          requests = {
            cpu    = "500m"
            memory = "1Gi"
          }
        }
        metrics = {
          enabled = true
          serviceMonitor = {
            enabled = true
          }
        }
      }

      # Application Server (API & UI)
      server = {
        replicas = var.enable_ha ? 2 : 1
        resources = {
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
          requests = {
            cpu    = "250m"
            memory = "256Mi"
          }
        }
        service = {
          type = "LoadBalancer"
          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-type"                              = "nlb"
            "service.beta.kubernetes.io/aws-load-balancer-scheme"                            = "internet-facing"
            "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "true"
          }
        }
        ingress = {
          enabled = false # Will configure separately with ALB if needed
        }
        metrics = {
          enabled = true
          serviceMonitor = {
            enabled = true
          }
        }
        # Enable insecure mode for initial setup (disable TLS at ArgoCD level, handle at LB)
        extraArgs = [
          "--insecure"
        ]
      }

      # Repo Server (connects to Git repos)
      repoServer = {
        replicas = var.enable_ha ? 2 : 1
        resources = {
          limits = {
            cpu    = "1000m"
            memory = "1Gi"
          }
          requests = {
            cpu    = "500m"
            memory = "512Mi"
          }
        }
        metrics = {
          enabled = true
          serviceMonitor = {
            enabled = true
          }
        }
      }

      # Redis for caching (HA mode)
      redis = {
        enabled = true
      }

      redis-ha = {
        enabled = var.enable_ha
        haproxy = {
          enabled  = var.enable_ha
          replicas = var.enable_ha ? 3 : 1
        }
      }

      # ApplicationSet Controller (manages multiple apps)
      applicationSet = {
        enabled  = true
        replicas = var.enable_ha ? 2 : 1
        metrics = {
          enabled = true
          serviceMonitor = {
            enabled = true
          }
        }
      }

      # Notifications Controller
      notifications = {
        enabled = true
        metrics = {
          enabled = true
          serviceMonitor = {
            enabled = true
          }
        }
      }

      # Dex (SSO/OAuth) - disabled for now, can enable later
      dex = {
        enabled = false
      }

      # Additional configurations
      configs = {
        params = {
          "server.insecure" = true
        }
        cm = {
          "application.instanceLabelKey" = "argocd.argoproj.io/instance"
          "timeout.reconciliation"       = "180s"

          # Resource customizations
          "resource.customizations" = <<-EOT
            networking.k8s.io/Ingress:
              health.lua: |
                hs = {}
                hs.status = "Healthy"
                return hs
          EOT
        }
        rbac = {
          "policy.default" = "role:readonly"
          "policy.csv"     = <<-EOT
            p, role:org-admin, applications, *, */*, allow
            p, role:org-admin, clusters, get, *, allow
            p, role:org-admin, repositories, *, *, allow
            p, role:org-admin, projects, *, *, allow
            g, admin, role:admin
          EOT
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.argocd]
}

# Create ArgoCD admin password secret (initial)
resource "kubernetes_secret" "argocd_initial_admin_secret" {
  metadata {
    name      = "argocd-initial-admin-secret"
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }

  data = {
    password = random_password.argocd_admin.result
  }

  type = "Opaque"

  lifecycle {
    ignore_changes = [data]
  }

  depends_on = [kubernetes_namespace.argocd]
}

# Generate random admin password
resource "random_password" "argocd_admin" {
  length  = 16
  special = true
}

# Store admin password in AWS Secrets Manager
resource "aws_secretsmanager_secret" "argocd_admin" {
  name        = "${var.cluster_name}-argocd-admin-password"
  description = "ArgoCD admin password for ${var.cluster_name}"

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-argocd-admin-password"
  })
}

resource "aws_secretsmanager_secret_version" "argocd_admin" {
  secret_id = aws_secretsmanager_secret.argocd_admin.id
  secret_string = jsonencode({
    username = "admin"
    password = random_password.argocd_admin.result
    url      = "https://argocd.${var.domain}"
  })
}
