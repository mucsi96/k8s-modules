locals {
  traefik_dashboard_host = "traefik.${var.dns_zone}"
}

resource "kubernetes_manifest" "traefik_dashboard_ingressroute" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "traefik-dashboard"
      namespace = kubernetes_namespace_v1.traefik.metadata[0].name
    }
    spec = {
      entryPoints = ["web"]
      routes = [
        {
          match = "Host(`${local.traefik_dashboard_host}`)"
          kind  = "Rule"
          services = [{
            name = "traefik-dashboard-oauth2-proxy"
            port = 80
          }]
        },
      ]
    }
  }

  depends_on = [helm_release.traefik_dashboard_oauth2_proxy]
}
