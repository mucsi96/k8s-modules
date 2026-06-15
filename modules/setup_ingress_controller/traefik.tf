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
    # All routing is via the Gateway API. Both of Traefik's own routing
    # providers are explicitly disabled — kubernetesIngress defaults to enabled
    # in the chart, so leaving it unset would keep the Ingress provider on.
    # The chart ships the standard-channel Gateway API CRDs in its crds/
    # directory (crds/gateway-standard-install.yaml), which Helm installs with
    # the release — so no separate CRD install is needed, same as Traefik's own
    # traefik.io CRDs.
    providers = {
      kubernetesCRD = {
        enabled = false
      }
      kubernetesIngress = {
        enabled = false
      }
      kubernetesGateway = {
        enabled = true
      }
    }
    # Let the chart create the GatewayClass (correct controllerName
    # traefik.io/gateway-controller); pin the name so gateway.tf can reference
    # it deterministically. The Gateway itself is defined in gateway.tf for
    # explicit control of the HTTPS listener cert + allowedRoutes.
    gatewayClass = {
      enabled = true
      name    = "traefik"
    }
    gateway = {
      enabled = false
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
        # cluster), so the entrypoint binds host port 443 (mapped to the
        # chart's default container port 8000). TLS is terminated by the
        # Gateway HTTPS listener on port 8000 (gateway.tf), which Traefik maps
        # to this entrypoint by matching port number — so no entrypoint-level
        # TLS here. The entrypoint keeps the name "web".
        hostPort = 443
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
