locals {
  name = "observatory"
  apps = concat(var.apps, [{
    name       = "Observatory"
    namespace  = local.name
    repository = "${var.github_repository_owner}/${var.github_repository}"
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

// Workloads are now owned by observatory-app's deployment pipeline. Preserve the
// live resources during the handoff; kubectl apply adopts the same names.
removed {
  from = kubernetes_deployment_v1.dashboard
  lifecycle { destroy = false }
}

removed {
  from = kubernetes_service_v1.dashboard
  lifecycle { destroy = false }
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
