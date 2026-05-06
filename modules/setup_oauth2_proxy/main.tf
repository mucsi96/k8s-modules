resource "random_password" "cookie_secret" {
  length  = 32
  special = false
}

locals {
  base_config_lines = [
    "email_domains = [\"*\"]",
    "cookie_name = \"_${var.name}\"",
    "cookie_secure = true",
    "reverse_proxy = true",
    "skip_provider_button = true",
    "silence_ping_logging = true",
    # Refresh the OIDC session before Entra's ~1h id_token expires so the
    # Authorization: Bearer id_token forwarded upstream stays valid; otherwise
    # kube-apiserver rejects it with "oidc: token is expired" once the original
    # id_token aged out and the SPA bounces back to the login screen.
    "cookie_refresh = \"30m\"",
  ]

  # session_cookie_minimal strips OAuth tokens from the session, which makes
  # injecting id_token / access_token into upstream requests impossible. Only
  # enable it when no header injection is configured.
  config_file = join("\n", concat(
    local.base_config_lines,
    length(var.inject_request_headers) == 0 ? ["session_cookie_minimal = true"] : [],
  ))

  session_storage = {
    type = "redis"
    redis = {
      password = var.session_redis.password
      standalone = {
        connectionUrl = var.session_redis.connection_url
      }
    }
  }
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
      configFile   = local.config_file
    }
    authenticatedEmailsFile = {
      enabled           = true
      restricted_access = "${var.valid_email}\n"
    }
    alphaConfig = {
      enabled = true
      configFile = yamlencode({
        injectRequestHeaders = var.inject_request_headers
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
          scope = var.scope
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
    sessionStorage = local.session_storage
  })]
}
