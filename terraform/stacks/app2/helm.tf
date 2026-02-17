provider "helm" {
  kubernetes {
    host                   = try(module.eks.cluster_endpoint, "")
    cluster_ca_certificate = try(base64decode(module.eks.cluster_certificate_authority_data), "")
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", try(module.eks.cluster_name, "dummy"), "--region", var.aws_region]
    }
  }
}

resource "helm_release" "app" {
  count = var.enable_helm_deployment ? 1 : 0

  name       = "myapp"
  chart      = "${path.module}/helm/app-chart"
  namespace  = "default"

  set {
    name  = "replicaCount"
    value = var.helm_replica_count
  }

  set {
    name  = "image.repository"
    value = var.helm_image_repository
  }

  set {
    name  = "image.tag"
    value = var.helm_image_tag
  }

  depends_on = [module.eks]
}
