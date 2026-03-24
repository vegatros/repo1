# -----------------------------------------------
# NGINX Ingress Controller
# -----------------------------------------------
resource "helm_release" "nginx_ingress" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true
  timeout          = 600
  wait             = true

  # Use NLB instead of Classic LB
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
    value = "nlb"
  }

  # Set as default IngressClass
  set {
    name  = "controller.ingressClassResource.default"
    value = "true"
  }

  # Linkerd sidecar injection
  set {
    name  = "controller.podAnnotations.linkerd\\.io/inject"
    value = "enabled"
  }

  depends_on = [
    module.eks,
    helm_release.linkerd_control_plane,
  ]
}
