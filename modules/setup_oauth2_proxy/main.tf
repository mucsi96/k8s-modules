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
  ]

  # session_cookie_minimal strips OAuth tokens from the session, which makes
  # injecting id_token / access_token into upstream requests impossible. Only
  # enable it when no header injection is configured. cookie_refresh requires
  # those same tokens (the refresh_token specifically) to be in the session, so
  # it's mutually exclusive with session_cookie_minimal -- enable refresh only
  # when we're already keeping tokens around to forward upstream. This is what
  # keeps Headlamp's Authorization: Bearer id_token from going stale and being
  # rejected by kube-apiserver as "oidc: token is expired".
  config_file = join("\n", concat(
    local.base_config_lines,
    length(var.inject_request_headers) == 0
    ? ["session_cookie_minimal = true"]
    : ["cookie_refresh = \"30m\""],
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
        injectRequestHeaders = [
          for header in var.inject_request_headers : {
            name = header.name
            values = [
              for value in header.values : {
                claimSource = merge(
                  { claim = value.claim },
                  value.prefix == null ? {} : { prefix = value.prefix },
                )
              }
            ]
          }
        ]
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
