resource "random_password" "cookie_secret" {
  length  = 32
  special = false
}

# The bundled Bitnami Redis subchart generates its own password on first
# install and refuses to re-roll it on upgrade unless you pass the old one,
# which is brittle to manage from Terraform. Owning the password here and
# pointing both the subchart and oauth2-proxy at the same Secret keeps
# upgrades idempotent.
resource "random_password" "redis_password" {
  count = var.session_store == "redis" ? 1 : 0

  length  = 32
  special = false
}

resource "kubernetes_secret_v1" "redis_auth" {
  count = var.session_store == "redis" ? 1 : 0

  metadata {
    name      = "${var.name}-oauth2-proxy-redis-auth"
    namespace = var.namespace
  }

  data = {
    redis-password = random_password.redis_password[0].result
  }

  type = "Opaque"
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

  redis_auth_secret_name = try(kubernetes_secret_v1.redis_auth[0].metadata[0].name, "")
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
        existingSecret = local.redis_auth_secret_name
      }
    }
    redis = {
      enabled = var.session_store == "redis"
      auth = {
        existingSecret = local.redis_auth_secret_name
      }
    }
  })]
}
