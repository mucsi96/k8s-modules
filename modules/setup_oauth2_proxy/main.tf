resource "random_password" "cookie_secret" {
  length  = 32
  special = false
}

resource "helm_release" "oauth2_proxy" {
  name       = "${var.name}-oauth2-proxy"
  repository = "https://oauth2-proxy.github.io/manifests"
  chart      = "oauth2-proxy"
  version    = var.oauth2_proxy_chart_version
  namespace  = var.namespace
  wait       = true
  timeout    = 600

  values = [yamlencode({
    image = {
      tag = var.oauth2_proxy_image_version
    }
    config = {
      cookieSecret = base64encode(random_password.cookie_secret.result)
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
          clientID     = var.client_id
          clientSecret = var.client_secret
          oidcConfig = {
            issuerURL      = "https://login.microsoftonline.com/${var.tenant_id}/v2.0"
            audienceClaims = ["aud"]
            emailClaim     = "email"
          }
          scope = "openid email profile User.Read"
        }]
        upstreamConfig = {
          upstreams = [{
            id   = var.name
            path = "/"
            uri  = var.upstream_uri
          }]
        }
      })
    }
    ingress = {
      enabled = false
    }
  })]
}
