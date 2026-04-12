# -----------------------------------------------
# Argo CD Installation via Helm
# -----------------------------------------------
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = "argocd"
  create_namespace = true
  timeout          = 600
  wait             = true

  # Server configuration — expose via NLB
  set {
    name  = "server.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "server.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
    value = "nlb"
  }

  set {
    name  = "server.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-scheme"
    value = "internet-facing"
  }

  # Enable TLS termination at Argo CD server
  set {
    name  = "server.extraArgs[0]"
    value = "--insecure"
  }

  # Disable Dex (use built-in auth)
  set {
    name  = "dex.enabled"
    value = "false"
  }

  # HA configuration for production
  set {
    name  = "redis-ha.enabled"
    value = var.environment == "prod" ? "true" : "false"
  }

  set {
    name  = "controller.replicas"
    value = var.environment == "prod" ? "2" : "1"
  }

  set {
    name  = "server.replicas"
    value = var.environment == "prod" ? "2" : "1"
  }

  set {
    name  = "repoServer.replicas"
    value = var.environment == "prod" ? "2" : "1"
  }

  depends_on = [module.eks]
}

# -----------------------------------------------
# Argo CD IRSA Role for accessing AWS resources
# -----------------------------------------------
resource "aws_iam_role" "argocd" {
  name = "${var.project_name}-argocd-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(module.eks.oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:argocd:argocd-server"
            "${replace(module.eks.oidc_provider_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Environment = var.environment
    Component   = "argocd"
  }
}
