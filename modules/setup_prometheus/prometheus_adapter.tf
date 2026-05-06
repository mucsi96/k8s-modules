# prometheus-adapter exposes custom and external metrics from Prometheus to the
# Kubernetes API. rules.default = false skips the default resource-metrics
# rules so the adapter does not register v1beta1.metrics.k8s.io and conflict
# with the existing metrics-server APIService. Add custom/external rules later
# as needed.
resource "helm_release" "prometheus_adapter" {
  name       = "prometheus-adapter"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus-adapter"
  version    = var.prometheus_adapter_chart_version
  namespace  = kubernetes_namespace_v1.prometheus.metadata[0].name
  wait       = true
  timeout    = 600

  values = [yamlencode({
    image = {
      tag = var.prometheus_adapter_image_version
    }
    prometheus = {
      url  = "http://${local.prometheus_service_name}.${kubernetes_namespace_v1.prometheus.metadata[0].name}.svc"
      port = local.prometheus_service_port
    }
    rules = {
      default  = false
      custom   = []
      external = []
    }
  })]

  depends_on = [helm_release.kube_prometheus_stack]
}
