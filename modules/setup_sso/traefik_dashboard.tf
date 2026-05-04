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
      namespace = var.traefik_namespace
    }
    spec = {
      redirectRegex = {
        regex       = "^https?://${local.traefik_dashboard_host_regex}/?$"
        replacement = "https://${local.traefik_dashboard_host}/dashboard/"
        permanent   = true
      }
    }
  }
}

resource "kubernetes_manifest" "traefik_dashboard_ingressroute" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "traefik-dashboard"
      namespace = var.traefik_namespace
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
              namespace = var.traefik_namespace
            },
          ]
          services = [{
            kind = "TraefikService"
            name = "api@internal"
          }]
        },
        {
          match = "Host(`${local.traefik_dashboard_host}`) && (PathPrefix(`/dashboard`) || PathPrefix(`/api`))"
          kind  = "Rule"
          middlewares = [
            {
              name      = "auth"
              namespace = kubernetes_namespace_v1.auth.metadata[0].name
            },
          ]
          services = [{
            kind = "TraefikService"
            name = "api@internal"
          }]
        },
      ]
    }
  }

  depends_on = [
    kubernetes_manifest.auth_chain,
    kubernetes_manifest.traefik_dashboard_redirect_root,
  ]
}
