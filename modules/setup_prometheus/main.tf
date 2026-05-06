locals {
  prometheus_name         = "prometheus"
  prometheus_service_name = "${local.prometheus_name}-server"
  prometheus_service_port = 80
}

resource "terraform_data" "wait_for" {
  input = var.wait_for
}

resource "kubernetes_namespace_v1" "prometheus" {
  metadata {
    name = "prometheus"
  }

  depends_on = [terraform_data.wait_for]
}

resource "helm_release" "prometheus" {
  name       = local.prometheus_name
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  version    = var.prometheus_chart_version
  namespace  = kubernetes_namespace_v1.prometheus.metadata[0].name
  wait       = true
  timeout    = 600

  values = [yamlencode({
    server = {
      image = {
        tag = var.prometheus_image_version
      }
      service = {
        type        = "ClusterIP"
        servicePort = local.prometheus_service_port
      }
      ingress = {
        enabled = false
      }
    }
    alertmanager = {
      enabled = false
    }
    prometheus-pushgateway = {
      enabled = false
    }
  })]
}

module "prometheus_oauth2_proxy" {
  source = "../setup_oauth2_proxy"

  name                       = "prometheus"
  namespace                  = kubernetes_namespace_v1.prometheus.metadata[0].name
  client_id                  = var.client_id
  client_secret              = var.client_secret
  tenant_id                  = var.tenant_id
  valid_email                = var.valid_email
  oauth2_proxy_chart_version = var.oauth2_proxy_chart_version
  oauth2_proxy_image_version = var.oauth2_proxy_image_version
  upstream_uri               = "http://${local.prometheus_service_name}.${kubernetes_namespace_v1.prometheus.metadata[0].name}.svc.cluster.local:${local.prometheus_service_port}"
  session_redis              = var.session_redis

  depends_on = [helm_release.prometheus]
}

resource "kubernetes_manifest" "prometheus_ingressroute" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "prometheus"
      namespace = kubernetes_namespace_v1.prometheus.metadata[0].name
    }
    spec = {
      entryPoints = ["web"]
      routes = [
        {
          match = "Host(`${var.hostname}`)"
          kind  = "Rule"
          services = [{
            name = module.prometheus_oauth2_proxy.service_name
            port = 80
          }]
        },
      ]
    }
  }

  depends_on = [module.prometheus_oauth2_proxy]
}
