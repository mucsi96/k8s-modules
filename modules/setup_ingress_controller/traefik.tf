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
    api = {
      insecure = true
    }
    service = {
      spec = {
        type = "ClusterIP"
      }
    }
    ports = {
      web = {
        # Cloudflare's edge connects straight to the node (single-node
        # cluster), so the entrypoint binds host port 443 and terminates TLS
        # with the Origin CA certificate (origin_certificate.tf). The
        # entrypoint keeps the name "web" because every IngressRoute — in
        # this repo and in the app repos — binds to it.
        hostPort = 443
        http = {
          tls = {
            enabled = true
          }
        }
        # X-Forwarded-* headers are only honored from the Cloudflare edge;
        # anything else would let a caller spoof the client IP seen by apps
        # and access logs.
        forwardedHeaders = {
          trustedIPs = concat(var.cloudflare_ipv4_cidrs, var.cloudflare_ipv6_cidrs)
        }
      }
      traefik = {
        expose = {
          default = true
        }
      }
    }
    # With hostPort on a single node the chart's default RollingUpdate
    # (maxSurge=1, maxUnavailable=0) deadlocks: the surging pod can never
    # bind 443 while the old pod holds it.
    updateStrategy = {
      type = "RollingUpdate"
      rollingUpdate = {
        maxSurge       = 0
        maxUnavailable = 1
      }
    }
  })]
}
