resource "kubernetes_namespace" "k8s_namespace" {
  metadata {
    name = "traefik"
  }
}

resource "helm_release" "traefik" {
  name       = "traefik"
  repository = "https://traefik.github.io/charts"
  chart      = "traefik"
  version    = var.traefik_chart_version
  namespace  = kubernetes_namespace.k8s_namespace.metadata[0].name
  wait       = true
  #https://github.com/traefik/traefik-helm-chart/blob/master/traefik/values.yaml
  values = [yamlencode({
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
    ports = {
      web = {
        redirections = {
          entryPoint = {
            to        = "websecure"
            scheme    = "https"
            permanent = true
          }
        }
      }
    }
    service = {
      spec = {
        type = "LoadBalancer"
      }
      annotations = {
        "service.beta.kubernetes.io/azure-load-balancer-resource-group" = data.azurerm_kubernetes_cluster.kubernetes_cluster.node_resource_group
        "service.beta.kubernetes.io/azure-pip-name"                     = var.resource_group_name
        "service.beta.kubernetes.io/azure-allowed-ip-ranges"            = var.ip_range
      }
    }
    tlsStore = {
      default = {
        defaultCertificate = {
          secretName = "traefik-default-cert"
        }
      }
    }
    extraObjects = [
      {
        apiVersion = "v1"
        kind       = "Secret"
        metadata = {
          name = "traefik-default-cert"
        }
        stringData = {
          "tls.crt" = acme_certificate.certificate.certificate_pem
          "tls.key" = acme_certificate.certificate.private_key_pem
        }
      }
    ]
  })]
}
