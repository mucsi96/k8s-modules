resource "random_password" "cookie_secret" {
  length  = 32
  special = false
}

# Per https://github.com/oauth2-proxy/manifests/issues/225 the Bitnami Redis
# subchart and oauth2-proxy each read the password from a different place:
# the subchart wants global.redis.password (it's what its pre-upgrade hook
# checks against the password baked into the existing PVC), and oauth2-proxy
# itself wants sessionStorage.redis.password to authenticate the connection.
# Generating it once in Terraform and feeding both keys keeps helm upgrades
# idempotent.
resource "random_password" "redis_password" {
  count = var.session_store == "redis" ? 1 : 0

  length  = 32
  special = false
}

locals {
  base_config_lines = [
    "email_domains = [\"*\"]",
    "cookie_secure = true",
    "reverse_proxy = true",
    "skip_provider_button = true",
    "silence_ping_logging = true",
  ]

  # session_cookie_minimal strips OAuth tokens from the session, which makes
  # injecting id_token / access_token into upstream requests impossible. Only
  # enable it when no header injection is configured.
  config_file = join("\n", concat(
    local.base_config_lines,
    length(var.inject_request_headers) == 0 ? ["session_cookie_minimal = true"] : [],
  ))

  redis_password = try(random_password.redis_password[0].result, "")
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
    sessionStorage = {
      type = var.session_store
      redis = {
        password = local.redis_password
      }
    }
    redis = {
      enabled = var.session_store == "redis"
      global = {
        redis = {
          password = local.redis_password
        }
      }
    }
  })]
}
