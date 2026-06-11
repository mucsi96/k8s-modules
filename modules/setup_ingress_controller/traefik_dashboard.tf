locals {
  # Traefik chart exposes its dashboard / admin API on the port named
  # `traefik`, which chart v39 sets to 8080 (older chart generations used
  # 9000). Inlining the number avoids a `data "kubernetes_service_v1"`
  # lookup that would otherwise need the apiserver to be reachable at plan
  # time. If a future chart upgrade changes the port, update this value to
  # match `ports.traefik.port` in the chart.
  traefik_admin_port           = 8080
  traefik_dashboard_host       = "traefik.${var.dns_zone}"
  traefik_dashboard_host_regex = replace(local.traefik_dashboard_host, ".", "\\.")
}

module "register_traefik_dashboard" {
  source = "../register_webapp"

  display_name  = "Traefik Dashboard - ${var.environment_name}"
  owner         = var.owner
  redirect_uris = ["https://${local.traefik_dashboard_host}/oauth2/callback"]
}

module "traefik_dashboard_oauth2_proxy" {
  source = "../setup_oauth2_proxy"

  name                       = "traefik-dashboard"
  namespace                  = kubernetes_namespace_v1.traefik.metadata[0].name
  client_id                  = module.register_traefik_dashboard.client_id
  client_secret              = module.register_traefik_dashboard.client_secret
  tenant_id                  = var.tenant_id
  valid_email                = var.valid_email
  oauth2_proxy_chart_version = var.oauth2_proxy_chart_version
  oauth2_proxy_image_version = var.oauth2_proxy_image_version
  upstream_uri               = "http://${helm_release.traefik.name}.${kubernetes_namespace_v1.traefik.metadata[0].name}.svc.cluster.local:${local.traefik_admin_port}"
  session_redis              = var.session_redis

  depends_on = [helm_release.traefik]
}

resource "kubectl_manifest" "traefik_dashboard_redirect_root_middleware" {
  yaml_body = yamlencode({
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "traefik-dashboard-redirect-root"
      namespace = kubernetes_namespace_v1.traefik.metadata[0].name
    }
    spec = {
      redirectRegex = {
        regex       = "^https?://${local.traefik_dashboard_host_regex}/?$"
        replacement = "https://${local.traefik_dashboard_host}/dashboard/"
        permanent   = true
      }
    }
  })

  depends_on = [helm_release.traefik]
}

resource "kubectl_manifest" "traefik_dashboard_ingressroute" {
  yaml_body = yamlencode({
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "traefik-dashboard"
      namespace = kubernetes_namespace_v1.traefik.metadata[0].name
    }
    spec = {
      entryPoints = ["web"]
      routes = [
        {
          match = "Host(`${local.traefik_dashboard_host}`) && Path(`/`)"
          kind  = "Rule"
          middlewares = [{
            name      = "traefik-dashboard-redirect-root"
            namespace = kubernetes_namespace_v1.traefik.metadata[0].name
          }]
          services = [{
            name = module.traefik_dashboard_oauth2_proxy.service_name
            port = 80
          }]
        },
        {
          match = "Host(`${local.traefik_dashboard_host}`)"
          kind  = "Rule"
          services = [{
            name = module.traefik_dashboard_oauth2_proxy.service_name
            port = 80
          }]
        },
      ]
    }
  })

  depends_on = [
    module.traefik_dashboard_oauth2_proxy,
    kubectl_manifest.traefik_dashboard_redirect_root_middleware,
  ]
}
