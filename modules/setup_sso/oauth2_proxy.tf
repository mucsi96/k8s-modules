resource "kubernetes_namespace_v1" "auth" {
  metadata {
    name = "auth"
  }
}

resource "random_password" "cookie_secret" {
  length  = 32
  special = false
}

resource "helm_release" "oauth2_proxy" {
  name       = "oauth2-proxy"
  repository = "https://oauth2-proxy.github.io/manifests"
  chart      = "oauth2-proxy"
  version    = var.oauth2_proxy_chart_version
  namespace  = kubernetes_namespace_v1.auth.metadata[0].name
  wait       = true
  timeout    = 600

  #https://github.com/oauth2-proxy/manifests/blob/main/helm/oauth2-proxy/values.yaml
  values = [yamlencode({
    config = {
      clientID     = azuread_application.oauth2_proxy.client_id
      clientSecret = azuread_application_password.oauth2_proxy.value
      cookieSecret = base64encode(substr(random_password.cookie_secret.result, 0, 32))
      configFile   = <<-EOT
        provider = "oidc"
        oidc_issuer_url = "https://login.microsoftonline.com/${var.tenant_id}/v2.0"
        redirect_url = "https://${local.auth_hostname}/oauth2/callback"
        cookie_domains = [".${var.dns_zone}"]
        whitelist_domains = [".${var.dns_zone}"]
        email_domains = ["*"]
        oidc_email_claim = "preferred_username"
        upstreams = ["static://202"]
        reverse_proxy = true
        set_xauthrequest = true
        pass_access_token = true
        pass_authorization_header = true
        cookie_secure = true
        skip_provider_button = true
      EOT
    }
    ingress = {
      enabled = false
    }
  })]
}

resource "kubernetes_manifest" "oauth2_proxy_ingressroute" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "oauth2-proxy"
      namespace = kubernetes_namespace_v1.auth.metadata[0].name
    }
    spec = {
      entryPoints = ["web"]
      routes = [{
        match = "Host(`${local.auth_hostname}`)"
        kind  = "Rule"
        services = [{
          name = "oauth2-proxy"
          port = 80
        }]
      }]
    }
  }

  depends_on = [helm_release.oauth2_proxy]
}

resource "kubernetes_manifest" "oauth2_proxy_forward_auth" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "oauth2-proxy-forward-auth"
      namespace = kubernetes_namespace_v1.auth.metadata[0].name
    }
    spec = {
      forwardAuth = {
        address            = "http://oauth2-proxy.${kubernetes_namespace_v1.auth.metadata[0].name}.svc.cluster.local/oauth2/auth"
        trustForwardHeader = true
        authResponseHeaders = [
          "X-Auth-Request-User",
          "X-Auth-Request-Email",
          "X-Auth-Request-Access-Token",
          "Authorization",
        ]
      }
    }
  }

  depends_on = [helm_release.oauth2_proxy]
}

resource "kubernetes_manifest" "oauth2_proxy_sign_in_redirect" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "oauth2-proxy-sign-in-redirect"
      namespace = kubernetes_namespace_v1.auth.metadata[0].name
    }
    spec = {
      errors = {
        status = ["401-403"]
        service = {
          name = "oauth2-proxy"
          port = 80
        }
        query = "/oauth2/sign_in?rd={url}"
      }
    }
  }

  depends_on = [helm_release.oauth2_proxy]
}

resource "kubernetes_manifest" "auth_chain" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "auth"
      namespace = kubernetes_namespace_v1.auth.metadata[0].name
    }
    spec = {
      chain = {
        middlewares = [
          {
            name      = "oauth2-proxy-sign-in-redirect"
            namespace = kubernetes_namespace_v1.auth.metadata[0].name
          },
          {
            name      = "oauth2-proxy-forward-auth"
            namespace = kubernetes_namespace_v1.auth.metadata[0].name
          },
        ]
      }
    }
  }

  depends_on = [
    kubernetes_manifest.oauth2_proxy_sign_in_redirect,
    kubernetes_manifest.oauth2_proxy_forward_auth,
  ]
}
