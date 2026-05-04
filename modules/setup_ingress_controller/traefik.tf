resource "kubernetes_namespace_v1" "traefik" {
  metadata {
    name = "traefik"
  }
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
