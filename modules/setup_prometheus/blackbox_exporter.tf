resource "helm_release" "blackbox_exporter" {
  name       = "blackbox-exporter"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus-blackbox-exporter"
  version    = var.prometheus_blackbox_exporter_chart_version
  namespace  = kubernetes_namespace_v1.prometheus.metadata[0].name
  wait       = true
  timeout    = 600

  values = [yamlencode({
    image = {
      tag = var.prometheus_blackbox_exporter_image_version
    }
    serviceMonitor = {
      enabled = true
    }
  })]

  depends_on = [helm_release.kube_prometheus_stack]
}
