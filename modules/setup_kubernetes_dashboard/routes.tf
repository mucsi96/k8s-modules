locals {
  dashboard_host = "${var.dashboard_subdomain}.${var.dns_zone}"
}

resource "helm_release" "dashboard_routes" {
  name      = "kubernetes-dashboard-routes"
  chart     = "${path.module}/charts/dashboard-routes"
  namespace = var.traefik_namespace

  values = [yamlencode({
    dashboardHost      = local.dashboard_host
    dashboardNamespace = kubernetes_namespace_v1.kubernetes_dashboard.metadata[0].name
    dashboardService   = "kubernetes-dashboard-kong-proxy"
    dashboardPort      = 443
    adminToken         = kubernetes_secret_v1.dashboard_admin_token.data.token
  })]

  depends_on = [helm_release.kubernetes_dashboard]
}
