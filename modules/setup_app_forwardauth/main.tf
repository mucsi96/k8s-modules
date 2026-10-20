locals {
  release_name = "${var.name}-oauth2-proxy"
}

resource "random_password" "cookie" {
  length  = 32
  special = false
}

resource "kubernetes_secret_v1" "credentials" {
  metadata {
    name      = "${local.release_name}-credentials"
    namespace = var.namespace
  }
  data = {
    client-id     = var.client_id
    client-secret = var.client_secret
    cookie-secret = base64encode(random_password.cookie.result)
  }
}

resource "kubernetes_secret_v1" "redis" {
  metadata {
    name      = "${local.release_name}-redis"
    namespace = var.namespace
  }
  data = {
    redis-password = var.session_redis.password
  }
}

resource "helm_release" "auth" {
  name       = local.release_name
  namespace  = var.namespace
  repository = "https://mucsi96.github.io/k8s-helm-charts"
  chart      = "oauth2-proxy-forwardauth"
  version    = "5.0.0"
  wait       = true
  timeout    = 600
  values = [yamlencode({
    global = {
      forwardAuth = {
        host              = var.hostname
        issuerURL         = "https://login.microsoftonline.com/${var.tenant_id}/v2.0"
        credentialsSecret = kubernetes_secret_v1.credentials.metadata[0].name
        mode              = var.mode
        apiScope          = var.mode == "api-token" && var.api_client_id != null ? "api://${var.api_client_id}/api-access" : ""
        trustedProxyCIDRs = var.trusted_proxy_cidrs
        # Chart 5 needs the explicit value during the app-owned policy cutover.
        # New proxy charts use this same fixed name.
        cookieName = "__Host-session"
      }
    }
    gateway = {
      name        = var.gateway_parent_ref.name
      namespace   = var.gateway_parent_ref.namespace
      sectionName = var.gateway_parent_ref.section_name
    }
    excludedRoutes = var.excluded_routes
    oauth2-proxy = {
      fullnameOverride = local.release_name
      sessionStorage = {
        redis = {
          existingSecret = kubernetes_secret_v1.redis.metadata[0].name
          standalone = {
            connectionUrl = var.session_redis.connection_url
          }
        }
      }
      podAnnotations = {
        "checksum/credentials" = sha256(jsonencode(kubernetes_secret_v1.credentials.data))
        "checksum/redis"       = sha256(jsonencode(kubernetes_secret_v1.redis.data))
      }
    }
  })]

  lifecycle {
    precondition {
      condition     = var.mode != "api-token" || try(length(trimspace(var.api_client_id)) > 0, false)
      error_message = "api-token mode requires api_client_id."
    }
  }
}
