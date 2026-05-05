module "register_traefik_dashboard" {
  source = "../register_webapp"

  display_name  = "Traefik Dashboard - ${var.environment_name}"
  owner         = var.owner
  redirect_uris = ["https://${local.traefik_dashboard_host}/oauth2/callback"]
}

resource "random_password" "traefik_dashboard_cookie_secret" {
  length  = 32
  special = false
}

resource "helm_release" "traefik_dashboard_oauth2_proxy" {
  name       = "traefik-dashboard-oauth2-proxy"
  repository = "https://oauth2-proxy.github.io/manifests"
  chart      = "oauth2-proxy"
  version    = var.oauth2_proxy_chart_version
  namespace  = kubernetes_namespace_v1.traefik.metadata[0].name
  wait       = true
  timeout    = 600

  values = [yamlencode({
    image = {
      tag = var.oauth2_proxy_image_version
    }
    config = {
      cookieSecret = base64encode(substr(random_password.traefik_dashboard_cookie_secret.result, 0, 32))
      configFile   = <<-EOT
        email_domains = ["*"]
        cookie_secure = true
        reverse_proxy = true
        skip_provider_button = true
        session_cookie_minimal = true
        silence_ping_logging = true
      EOT
    }
    authenticatedEmailsFile = {
      enabled           = true
      restricted_access = "${var.valid_email}\n"
    }
    alphaConfig = {
      enabled = true
      configFile = yamlencode({
        providers = [{
          id           = "entra"
          provider     = "oidc"
          clientID     = module.register_traefik_dashboard.client_id
          clientSecret = module.register_traefik_dashboard.client_secret
          oidcConfig = {
            issuerURL      = "https://login.microsoftonline.com/${var.tenant_id}/v2.0"
            audienceClaims = ["aud"]
            emailClaim     = "email"
          }
          scope = "openid email profile User.Read"
        }]
        upstreamConfig = {
          upstreams = [{
            id   = "traefik-dashboard"
            path = "/"
            uri  = "http://traefik.${kubernetes_namespace_v1.traefik.metadata[0].name}.svc.cluster.local:9000"
          }]
        }
      })
    }
    ingress = {
      enabled = false
    }
  })]

  depends_on = [helm_release.traefik]
}
