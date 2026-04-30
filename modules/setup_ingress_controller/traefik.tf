resource "kubernetes_namespace_v1" "traefik" {
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
  namespace  = kubernetes_namespace_v1.traefik.metadata[0].name
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
      web = {
        forwardedHeaders = {
          insecure = true
        }
      }
    }
  })]
}

resource "helm_release" "traefik_routes" {
  name      = "traefik-routes"
  chart     = "${path.module}/charts/traefik-routes"
  namespace = kubernetes_namespace_v1.traefik.metadata[0].name

  values = [yamlencode({
    dashboardRegex       = "^https?://${local.traefik_dashboard_host_regex}/?$"
    dashboardReplacement = "https://${local.traefik_dashboard_host}/dashboard/"
    dashboardMatch       = "Host(`${local.traefik_dashboard_host}`) && Path(`/`)"
  })]

  depends_on = [helm_release.traefik]
}
