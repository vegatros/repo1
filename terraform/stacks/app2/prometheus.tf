# -----------------------------------------------
# Prometheus Stack with AMP Remote Write
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

  # Disable Grafana (using Amazon Managed Grafana)
  set {
    name  = "grafana.enabled"
    value = "false"
  }

  # Configure ServiceAccount with IRSA
  set {
    name  = "prometheus.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = "arn:aws:iam::925185632967:role/PrometheusAMPWriteRole"
  }

  # Configure remote write to Amazon Managed Prometheus
  set {
    name  = "prometheus.prometheusSpec.remoteWrite[0].url"
    value = "https://aps-workspaces.us-east-1.amazonaws.com/workspaces/ws-b97416f6-3a57-4891-b814-3b039d6756f2/api/v1/remote_write"
  }

  set {
    name  = "prometheus.prometheusSpec.remoteWrite[0].sigv4.region"
    value = "us-east-1"
  }

  depends_on = [
    helm_release.linkerd_control_plane,
  ]
}
