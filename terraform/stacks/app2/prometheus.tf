# -----------------------------------------------
# Prometheus Stack
# -----------------------------------------------
resource "helm_release" "prometheus" {
  name             = "prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = "monitoring"
  create_namespace = true
  timeout          = 600
  wait             = false

  set {
    name  = "prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues"
    value = "false"
  }

  set {
    name  = "prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues"
    value = "false"
  }

  # Enable Linkerd injection
  set {
    name  = "prometheus.prometheusSpec.podMetadata.annotations.linkerd\\.io/inject"
    value = "enabled"
  }

  set {
    name  = "grafana.podAnnotations.linkerd\\.io/inject"
    value = "enabled"
  }

  depends_on = [
    helm_release.linkerd_control_plane,
  ]
}
