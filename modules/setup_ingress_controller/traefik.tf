resource "kubernetes_namespace_v1" "traefik" {
  metadata {
    name = "traefik"
  }
}

locals {
  traefik_dashboard_host = "traefik.${var.dns_zone}"
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
    providers = {
      kubernetesCRD = {
        allowCrossNamespace = true
      }
    }
    ingressRoute = {
      dashboard = {
        enabled = false
      }
    }
    service = {
      spec = {
        type = "ClusterIP"
      }
    }
    ports = {
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
    host             = local.traefik_dashboard_host
    ssoAuthHostname  = var.sso_auth_hostname
    ssoNamespace     = var.sso_namespace
    ssoServiceName   = var.sso_service_name
    ssoServicePort   = var.sso_service_port
  })]

  depends_on = [helm_release.traefik]
}
