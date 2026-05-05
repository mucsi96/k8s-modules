module "register_webapp" {
  source = "../register_webapp"

  display_name  = "${var.display_name} - ${var.environment_name}"
  owner         = var.owner
  redirect_uris = ["https://${var.hostname}/oauth2/callback"]
}

resource "random_password" "cookie_secret" {
  length  = 32
  special = false
}

locals {
  release_name  = "${var.name}-oauth2-proxy"
  hostname_re   = replace(var.hostname, ".", "\\.")
  redirect_root = var.redirect_root_to != null
}

resource "helm_release" "oauth2_proxy" {
  name       = local.release_name
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
      cookieSecret = base64encode(substr(random_password.cookie_secret.result, 0, 32))
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
          clientID     = module.register_webapp.client_id
          clientSecret = module.register_webapp.client_secret
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

resource "kubernetes_manifest" "redirect_root_middleware" {
  count = local.redirect_root ? 1 : 0

  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "${var.name}-redirect-root"
      namespace = var.namespace
    }
    spec = {
      redirectRegex = {
        regex       = "^https?://${local.hostname_re}/?$"
        replacement = "https://${var.hostname}${var.redirect_root_to}"
        permanent   = true
      }
    }
  }
}

locals {
  upstream_service = {
    name = local.release_name
    port = 80
  }
  redirect_route = {
    match = "Host(`${var.hostname}`) && Path(`/`)"
    kind  = "Rule"
    middlewares = [{
      name      = "${var.name}-redirect-root"
      namespace = var.namespace
    }]
    services = [local.upstream_service]
  }
  catchall_route = {
    match       = "Host(`${var.hostname}`)"
    kind        = "Rule"
    middlewares = []
    services    = [local.upstream_service]
  }
  routes = local.redirect_root ? [local.redirect_route, local.catchall_route] : [local.catchall_route]
}

resource "kubernetes_manifest" "ingressroute" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = var.name
      namespace = var.namespace
    }
    spec = {
      entryPoints = [var.entry_point]
      routes      = local.routes
    }
  }

  depends_on = [
    helm_release.oauth2_proxy,
    kubernetes_manifest.redirect_root_middleware,
  ]
}
