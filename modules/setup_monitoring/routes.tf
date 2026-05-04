resource "helm_release" "monitoring_routes" {
  name      = "monitoring-routes"
  chart     = "${path.module}/charts/monitoring-routes"
  namespace = kubernetes_namespace_v1.monitoring.metadata[0].name

  values = [yamlencode({
    grafanaHost          = local.grafana_host
    prometheusHost       = local.prometheus_host
    dashboardHost        = local.dashboard_host
    dashboardBearerToken = kubernetes_secret_v1.kubernetes_dashboard_admin_token.data.token
  })]

  depends_on = [
    helm_release.kube_prometheus_stack,
    helm_release.kubernetes_dashboard,
  ]
}
