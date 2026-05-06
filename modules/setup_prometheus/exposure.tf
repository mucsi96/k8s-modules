module "prometheus_oauth2_proxy" {
  source = "../setup_oauth2_proxy"

  name                       = "prometheus"
  namespace                  = kubernetes_namespace_v1.prometheus.metadata[0].name
  client_id                  = var.prometheus_client_id
  client_secret              = var.prometheus_client_secret
  tenant_id                  = var.tenant_id
  valid_email                = var.valid_email
  oauth2_proxy_chart_version = var.oauth2_proxy_chart_version
  oauth2_proxy_image_version = var.oauth2_proxy_image_version
  upstream_uri               = "http://${local.prometheus_service_name}.${kubernetes_namespace_v1.prometheus.metadata[0].name}.svc.cluster.local:${local.prometheus_service_port}"
  session_redis              = var.session_redis

  depends_on = [helm_release.kube_prometheus_stack]
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
          match = "Host(`${var.prometheus_hostname}`)"
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

module "grafana_oauth2_proxy" {
  source = "../setup_oauth2_proxy"

  name                       = "grafana"
  namespace                  = kubernetes_namespace_v1.prometheus.metadata[0].name
  client_id                  = var.grafana_client_id
  client_secret              = var.grafana_client_secret
  tenant_id                  = var.tenant_id
  valid_email                = var.valid_email
  oauth2_proxy_chart_version = var.oauth2_proxy_chart_version
  oauth2_proxy_image_version = var.oauth2_proxy_image_version
  upstream_uri               = "http://${local.grafana_service_name}.${kubernetes_namespace_v1.prometheus.metadata[0].name}.svc.cluster.local:${local.grafana_service_port}"
  session_redis              = var.session_redis

  # Forward identity to Grafana's auth-proxy mode so it can auto-provision the
  # signed-in user and skip its own login form.
  inject_request_headers = [
    {
      name = "X-WEBAUTH-USER"
      values = [{
        claim = "email"
      }]
    },
    {
      name = "X-WEBAUTH-EMAIL"
      values = [{
        claim = "email"
      }]
    },
  ]

  depends_on = [helm_release.kube_prometheus_stack]
}

resource "kubernetes_manifest" "grafana_ingressroute" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "grafana"
      namespace = kubernetes_namespace_v1.prometheus.metadata[0].name
    }
    spec = {
      entryPoints = ["web"]
      routes = [
        {
          match = "Host(`${var.grafana_hostname}`)"
          kind  = "Rule"
          services = [{
            name = module.grafana_oauth2_proxy.service_name
            port = 80
          }]
        },
      ]
    }
  }

  depends_on = [module.grafana_oauth2_proxy]
}
