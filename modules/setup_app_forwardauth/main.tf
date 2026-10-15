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
  version    = "1.0.0"
  wait       = true
  timeout    = 600
  values = [yamlencode({
    global = {
      forwardAuth = {
        host              = var.hostname
        issuerURL         = "https://login.microsoftonline.com/${var.tenant_id}/v2.0"
        credentialsSecret = kubernetes_secret_v1.credentials.metadata[0].name
        mode              = "api-token"
        apiScope          = "api://${var.api_client_id}/api-access"
        trustedProxyCIDRs = var.trusted_proxy_cidrs
      }
    }
    gateway = {
      name        = var.gateway_parent_ref.name
      namespace   = var.gateway_parent_ref.namespace
      sectionName = var.gateway_parent_ref.section_name
    }
    machineRoutes = var.machine_routes
    oauth2-proxy = {
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
}

resource "kubernetes_network_policy_v1" "app" {
  for_each = var.protected_apps
  metadata {
    name      = "${each.key}-ingress"
    namespace = var.namespace
  }
  spec {
    pod_selector {
      match_labels = { app = each.key }
    }
    policy_types = ["Ingress"]
    ingress {
      from {
        namespace_selector {
          match_labels = { "kubernetes.io/metadata.name" = "kube-system" }
        }
        pod_selector {
          match_labels = { "app.kubernetes.io/name" = "traefik" }
        }
      }
      ports {
        protocol = "TCP"
        port     = each.value.port
      }
    }
    dynamic "ingress" {
      for_each = each.value.management_port == null ? [] : [each.value.management_port]
      content {
        from {
          namespace_selector {
            match_labels = { "kubernetes.io/metadata.name" = "monitoring" }
          }
        }
        ports {
          protocol = "TCP"
          port     = ingress.value
        }
      }
    }
  }
}
