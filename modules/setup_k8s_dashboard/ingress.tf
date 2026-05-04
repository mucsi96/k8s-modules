resource "kubernetes_manifest" "dashboard_ingressroute" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "kubernetes-dashboard"
      namespace = kubernetes_namespace_v1.dashboard.metadata[0].name
    }
    spec = {
      entryPoints = ["web"]
      routes = [{
        match = "Host(`${local.dashboard_hostname}`)"
        kind  = "Rule"
        middlewares = [
          {
            name      = var.auth_middleware_name
            namespace = var.auth_middleware_namespace
          },
        ]
        services = [{
          name = "kubernetes-dashboard-kong-proxy"
          port = 80
        }]
      }]
    }
  }

  depends_on = [helm_release.kubernetes_dashboard]
}
