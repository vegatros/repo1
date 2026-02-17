provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

resource "helm_release" "app" {
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
