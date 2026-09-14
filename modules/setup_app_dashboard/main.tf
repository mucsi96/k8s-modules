locals {
  name = "observatory"
  apps = concat(var.apps, [{
    name       = "Observatory"
    namespace  = local.name
    repository = "mucsi96/p07"
    url        = "https://${nonsensitive(var.hostname)}"
  }])
}

resource "terraform_data" "ready" { input = var.wait_for }

resource "kubernetes_namespace_v1" "dashboard" {
  metadata { name = local.name }
  depends_on = [terraform_data.ready]
}

resource "kubernetes_service_account_v1" "dashboard" {
  metadata {
    name      = local.name
    namespace = kubernetes_namespace_v1.dashboard.metadata[0].name
  }
}

# Deployment readiness and images only. No secrets, logs, exec, or write access.
resource "kubernetes_role_v1" "reader" {
  for_each = toset([for app in local.apps : app.namespace])
  metadata {
    name      = "observatory-reader"
    namespace = each.value
  }
  rule {
    api_groups = ["apps"]
    resources  = ["deployments"]
    verbs      = ["list"]
  }
  depends_on = [kubernetes_namespace_v1.dashboard]
}

resource "kubernetes_role_binding_v1" "reader" {
  for_each = kubernetes_role_v1.reader
  metadata {
    name      = "observatory-reader"
    namespace = each.value.metadata[0].namespace
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = each.value.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.dashboard.metadata[0].name
    namespace = kubernetes_namespace_v1.dashboard.metadata[0].name
  }
}

resource "kubernetes_config_map_v1" "dashboard" {
  metadata {
    name      = local.name
    namespace = kubernetes_namespace_v1.dashboard.metadata[0].name
  }
  data = { "config.json" = jsonencode({ environment = var.environment_name, apps = local.apps }) }
}

resource "kubernetes_secret_v1" "github" {
  metadata {
    name      = "observatory-github"
    namespace = kubernetes_namespace_v1.dashboard.metadata[0].name
  }
  data = { token = var.github_token }
}

resource "kubernetes_deployment_v1" "dashboard" {
  metadata {
    name      = local.name
    namespace = kubernetes_namespace_v1.dashboard.metadata[0].name
  }
  spec {
    replicas = 1
    selector { match_labels = { app = local.name } }
    template {
      metadata {
        labels = { app = local.name }
        annotations = {
          "checksum/config" = sha256(kubernetes_config_map_v1.dashboard.data["config.json"])
          "checksum/token"  = sha256(var.github_token)
        }
      }
      spec {
        service_account_name = kubernetes_service_account_v1.dashboard.metadata[0].name
        security_context {
          run_as_non_root = true
          run_as_user     = 65532
          fs_group        = 65532
          seccomp_profile { type = "RuntimeDefault" }
        }
        container {
          name  = local.name
          image = var.image
          port { container_port = 8080 }
          env {
            name  = "CONFIG_FILE"
            value = "/config/config.json"
          }
          env {
            name = "GITHUB_TOKEN"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.github.metadata[0].name
                key  = "token"
              }
            }
          }
          volume_mount {
            name       = "config"
            mount_path = "/config"
            read_only  = true
          }
          resources {
            requests = { cpu = "5m", memory = "32Mi" }
            limits   = { memory = "128Mi" }
          }
          security_context {
            read_only_root_filesystem  = true
            allow_privilege_escalation = false
            capabilities { drop = ["ALL"] }
          }
          readiness_probe {
            http_get {
              path = "/healthz"
              port = 8080
            }
          }
          liveness_probe {
            http_get {
              path = "/healthz"
              port = 8080
            }
            initial_delay_seconds = 5
          }
        }
        volume {
          name = "config"
          config_map { name = kubernetes_config_map_v1.dashboard.metadata[0].name }
        }
      }
    }
  }
  depends_on = [kubernetes_role_binding_v1.reader]
}

resource "kubernetes_service_v1" "dashboard" {
  metadata {
    name      = local.name
    namespace = kubernetes_namespace_v1.dashboard.metadata[0].name
  }
  spec {
    selector = { app = local.name }
    port {
      port        = 8080
      target_port = 8080
    }
  }
}

module "registration" {
  source        = "../register_webapp"
  display_name  = "Observatory - ${var.environment_name}"
  owner         = var.owner
  redirect_uris = ["https://${var.hostname}/oauth2/callback"]
}

module "oauth2_proxy" {
  source                     = "../setup_oauth2_proxy"
  name                       = local.name
  namespace                  = kubernetes_namespace_v1.dashboard.metadata[0].name
  client_id                  = module.registration.client_id
  client_secret              = module.registration.client_secret
  tenant_id                  = var.tenant_id
  valid_email                = var.valid_email
  oauth2_proxy_chart_version = var.oauth2_proxy_chart_version
  oauth2_proxy_image_version = var.oauth2_proxy_image_version
  session_redis              = var.session_redis
  upstream_uri               = "http://${local.name}:8080"
}

resource "kubectl_manifest" "route" {
  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata   = { name = local.name, namespace = kubernetes_namespace_v1.dashboard.metadata[0].name }
    spec = {
      parentRefs = [{
        group       = "gateway.networking.k8s.io"
        kind        = "Gateway"
        name        = var.gateway_parent_ref.name
        namespace   = var.gateway_parent_ref.namespace
        sectionName = var.gateway_parent_ref.section_name
      }]
      hostnames = [var.hostname]
      rules     = [{ backendRefs = [{ name = module.oauth2_proxy.service_name, port = 80 }] }]
    }
  })
}

# The app trusts the OIDC proxy boundary; only that proxy may reach its HTTP port.
resource "kubernetes_network_policy_v1" "dashboard" {
  metadata {
    name      = local.name
    namespace = kubernetes_namespace_v1.dashboard.metadata[0].name
  }
  spec {
    pod_selector { match_labels = { app = local.name } }
    policy_types = ["Ingress"]
    ingress {
      from {
        pod_selector {
          match_labels = { "app.kubernetes.io/instance" = "${local.name}-oauth2-proxy" }
        }
      }
      ports {
        port     = "8080"
        protocol = "TCP"
      }
    }
  }
}

output "url" { value = "https://${nonsensitive(var.hostname)}" }
