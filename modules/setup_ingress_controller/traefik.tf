resource "kubernetes_namespace" "traefik" {
  metadata {
    name = "traefik"
  }
}

locals {
  traefik_dashboard_host       = "traefik.${var.dns_zone}"
  traefik_dashboard_host_regex = replace(local.traefik_dashboard_host, ".", "\\.")
}

resource "helm_release" "traefik" {
  name       = "traefik"
  repository = "https://traefik.github.io/charts"
  chart      = "traefik"
  version    = var.traefik_chart_version
  namespace  = kubernetes_namespace.traefik.metadata[0].name
  wait       = true
  timeout    = 600
  #https://github.com/traefik/traefik-helm-chart/blob/master/traefik/values.yaml
  values = [yamlencode({
    versionOverride = var.traefik_version
    logs = {
      general = {
        level = "DEBUG"
      }
      access = {
        enabled = true
      }
    }
    ingressRoute = {
      dashboard = {
        enabled = true
      }
    }
    service = {
      spec = {
        type = "ClusterIP"
      }
    }
    ports = {
      traefik = {
        expose = {
          default = true
        }
      }
    }
  })]
}

resource "kubernetes_manifest" "traefik_redirect_root_to_dashboard" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "redirect-root-to-dashboard"
      namespace = kubernetes_namespace.traefik.metadata[0].name
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

resource "kubernetes_manifest" "traefik_dashboard_ingress_route" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "traefik-dashboard-redirect-root-to-dashboard"
      namespace = kubernetes_namespace.traefik.metadata[0].name
    }
    spec = {
      entryPoints = ["traefik"]
      routes = [
        {
          match = "Host(`${local.traefik_dashboard_host}`) && Path(`/`)"
          kind  = "Rule"
          middlewares = [
            {
              name      = "redirect-root-to-dashboard"
              namespace = kubernetes_namespace.traefik.metadata[0].name
            }
          ]
          services = [
            {
              kind = "TraefikService"
              name = "api@internal"
            }
          ]
        }
      ]
    }
  }

  depends_on = [
    helm_release.traefik,
    kubernetes_manifest.traefik_redirect_root_to_dashboard
  ]
}
