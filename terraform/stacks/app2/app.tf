# -----------------------------------------------
# Application Deployment via Helm
# -----------------------------------------------
resource "helm_release" "app" {
  name             = "${var.project_name}-app"
  chart            = "${path.module}/helm/app-chart"
  namespace        = "app-${var.environment}"
  create_namespace = true
  timeout          = 600
  wait             = false
  atomic           = false

  values = [
    file("${path.module}/helm/app-chart/values.yaml"),
    file("${path.module}/helm/app-chart/values-${var.environment}.yaml"),
  ]

  depends_on = [
    helm_release.linkerd_control_plane,
    helm_release.nginx_ingress,
  ]
}
