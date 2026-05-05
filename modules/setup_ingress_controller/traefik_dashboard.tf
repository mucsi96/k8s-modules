locals {
  traefik_dashboard_host       = "traefik.${var.dns_zone}"
  traefik_dashboard_host_regex = replace(local.traefik_dashboard_host, ".", "\\.")
}

resource "kubernetes_manifest" "traefik_dashboard_redirect_root" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "traefik-dashboard-redirect-root"
      namespace = kubernetes_namespace_v1.traefik.metadata[0].name
    }
    spec = {
      redirectRegex = {
        regex       = "^https?://${local.traefik_dashboard_host_regex}/?$"
        replacement = "https://${local.traefik_dashboard_host}/dashboard/"
        permanent   = true
      }
    }
  }

  depends_on = [helm_release.traefik]
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
          match = "Host(`${local.traefik_dashboard_host}`) && Path(`/`)"
          kind  = "Rule"
          middlewares = [
            {
              name      = "traefik-dashboard-redirect-root"
              namespace = kubernetes_namespace_v1.traefik.metadata[0].name
            },
          ]
          services = [{
            name = "traefik-dashboard-oauth2-proxy"
            port = 80
          }]
        },
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

  depends_on = [
    helm_release.traefik_dashboard_oauth2_proxy,
    kubernetes_manifest.traefik_dashboard_redirect_root,
  ]
}
