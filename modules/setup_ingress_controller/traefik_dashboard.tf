data "kubernetes_service_v1" "traefik" {
  metadata {
    name      = helm_release.traefik.name
    namespace = kubernetes_namespace_v1.traefik.metadata[0].name
  }
}

locals {
  traefik_admin_port     = one([for p in data.kubernetes_service_v1.traefik.spec[0].port : p.port if p.name == "traefik"])
  traefik_dashboard_host = "traefik.${var.dns_zone}"
}

module "traefik_dashboard_oauth2_proxy" {
  source = "../setup_oauth2_proxy"

  name                       = "traefik-dashboard"
  namespace                  = kubernetes_namespace_v1.traefik.metadata[0].name
  hostname                   = local.traefik_dashboard_host
  display_name               = "Traefik Dashboard"
  environment_name           = var.environment_name
  owner                      = var.owner
  tenant_id                  = var.tenant_id
  valid_email                = var.valid_email
  oauth2_proxy_chart_version = var.oauth2_proxy_chart_version
  oauth2_proxy_image_version = var.oauth2_proxy_image_version
  upstream_uri               = "http://${helm_release.traefik.name}.${kubernetes_namespace_v1.traefik.metadata[0].name}.svc.cluster.local:${local.traefik_admin_port}"
  redirect_root_to           = "/dashboard/"

  depends_on = [helm_release.traefik]
}
