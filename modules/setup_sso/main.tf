locals {
  release_name = "oauth2-proxy"
}

resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = var.namespace
  }
}

resource "random_password" "cookie_secret" {
  length  = 32
  special = false
}

resource "helm_release" "oauth2_proxy" {
  name       = local.release_name
  repository = "https://oauth2-proxy.github.io/manifests"
  chart      = "oauth2-proxy"
  version    = var.chart_version
  namespace  = kubernetes_namespace_v1.this.metadata[0].name
  wait       = true
  timeout    = 600

  # https://github.com/oauth2-proxy/manifests/blob/main/helm/oauth2-proxy/values.yaml
  values = [yamlencode({
    config = {
      clientID     = var.client_id
      clientSecret = var.client_secret
      cookieSecret = random_password.cookie_secret.result
      configFile = join("\n", [
        "provider = \"oidc\"",
        "oidc_issuer_url = \"https://login.microsoftonline.com/${var.tenant_id}/v2.0\"",
        "redirect_url = \"${var.redirect_url}\"",
        "upstreams = [\"static://202\"]",
        "email_domains = [\"*\"]",
        "scope = \"openid email profile\"",
        "cookie_secure = true",
        "cookie_domains = [\"${var.cookie_domain}\"]",
        "whitelist_domains = ${jsonencode(var.whitelist_domains)}",
        "set_xauthrequest = true",
        "skip_provider_button = true",
        "reverse_proxy = true",
      ])
    }
    service = {
      portNumber = 80
    }
  })]
}
