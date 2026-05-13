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
  needs_session_tokens = length(var.inject_request_headers) > 0 || var.basic_auth_password != ""

  config_file = join("\n", concat(
    local.base_config_lines,
    local.needs_session_tokens ? ["cookie_refresh = \"30m\""] : ["session_cookie_minimal = true"],
  ))

  user_inject_request_headers = [
    for header in var.inject_request_headers : {
      name = header.name
      values = [
        for value in header.values : merge(
          { claim = value.claim },
          value.prefix == null ? {} : { prefix = value.prefix },
        )
      ]
    }
  ]

  # alphaConfig replacement for the legacy pass_basic_auth /
  # basic_auth_password cfg keys, which oauth2-proxy 7.x rejects with
  # "invalid keys" at startup. Setting basicAuthPassword on a header value
  # tells oauth2-proxy to construct 'Authorization: Basic
  # base64(<email>:<password>)' upstream by combining the email claim with
  # the static password defined here. The chart's YAML marshaller turns
  # the base64-encoded value into the right []byte representation that
  # oauth2-proxy expects for SecretSource.Value.
  basic_auth_inject_headers = var.basic_auth_password == "" ? [] : [{
    name = "Authorization"
    values = [{
      claim = "email"
      basicAuthPassword = {
        value = base64encode(var.basic_auth_password)
      }
    }]
  }]

  inject_request_headers = concat(
    local.user_inject_request_headers,
    local.basic_auth_inject_headers,
  )

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
  timeout    = 120

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
        injectRequestHeaders = local.inject_request_headers
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
