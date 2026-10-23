locals {
  ingress_controller_namespace = "kube-system"
  gateway_namespace            = "traefik"
  gateway_name                 = "traefik"
  gateway_listener_name        = "websecure"
}

resource "kubernetes_namespace_v1" "gateway" {
  metadata {
    name = local.gateway_namespace
  }
}

# k3s owns the Traefik Helm release. HelmChartConfig overlays the values of the
# packaged chart without introducing a second release or controller.
resource "kubectl_manifest" "traefik_config" {
  yaml_body = yamlencode({
    apiVersion = "helm.cattle.io/v1"
    kind       = "HelmChartConfig"
    metadata = {
      name      = "traefik"
      namespace = local.ingress_controller_namespace
    }
    spec = {
      valuesContent = yamlencode(merge({
        logs = {
          general = {
            level = "INFO"
          }
          access = {
            enabled = true
          }
        }
        providers = {
          kubernetesCRD = {
            enabled = var.enable_forward_auth || var.enable_index_config
          }
          kubernetesIngress = {
            enabled = false
          }
          kubernetesGateway = {
            enabled = true
          }
        }
        gatewayClass = {
          enabled = true
          name    = "traefik"
        }
        gateway = {
          enabled = false
        }
        service = {
          spec = {
            type = "ClusterIP"
          }
        }
        ports = {
          web = {
            expose = {
              default = false
            }
          }
          websecure = {
            hostPort = 443
            forwardedHeaders = {
              trustedIPs = concat(var.cloudflare_ipv4_cidrs, var.cloudflare_ipv6_cidrs)
            }
          }
        }
        resources = {
          requests = {
            cpu    = "10m"
            memory = "64Mi"
          }
          limits = {
            memory = "128Mi"
          }
        }
        updateStrategy = {
          type = "RollingUpdate"
          rollingUpdate = {
            maxSurge       = 0
            maxUnavailable = 1
          }
        }
        }, var.enable_index_config ? {
        experimental = {
          plugins = {
            rewritebody = {
              moduleName = "github.com/traefik/plugin-rewritebody"
              version    = "v0.3.1"
            }
          }
        }
      } : {}))
    }
  })
}
