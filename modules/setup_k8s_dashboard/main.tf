locals {
  headlamp_name = "headlamp"
  headlamp_port = 80
}

resource "terraform_data" "wait_for" {
  input = var.wait_for
}

resource "kubernetes_namespace_v1" "k8s_dashboard" {
  metadata {
    name = "k8s-dashboard"
  }

  depends_on = [terraform_data.wait_for]
}

resource "helm_release" "headlamp" {
  name       = local.headlamp_name
  repository = "https://kubernetes-sigs.github.io/headlamp/"
  chart      = "headlamp"
  version    = var.headlamp_chart_version
  namespace  = kubernetes_namespace_v1.k8s_dashboard.metadata[0].name
  wait       = true
  timeout    = 600

  values = [yamlencode({
    image = {
      tag = var.headlamp_image_version
    }
    serviceAccount = {
      create = true
    }
    clusterRoleBinding = {
      create          = true
      clusterRoleName = "view"
    }
    service = {
      type = "ClusterIP"
      port = local.headlamp_port
    }
    ingress = {
      enabled = false
    }
  })]
}

# oauth2-proxy authenticates *who can open the dashboard* but does not forward
# the user's token to Headlamp. Headlamp talks to the apiserver as its own
# in-cluster ServiceAccount (created by the helm chart above with
# clusterRoleBinding.create = true / clusterRoleName = "view"), so the
# apiserver-trusted Entra audience and the dashboard sign-in audience stay
# decoupled. Every authorized user sees the same `view` of the cluster; per-
# user RBAC inside the dashboard is intentionally not modelled here.
module "headlamp_oauth2_proxy" {
  source = "../setup_oauth2_proxy"

  name                       = "headlamp"
  namespace                  = kubernetes_namespace_v1.k8s_dashboard.metadata[0].name
  client_id                  = var.client_id
  client_secret              = var.client_secret
  tenant_id                  = var.tenant_id
  valid_email                = var.valid_email
  oauth2_proxy_chart_version = var.oauth2_proxy_chart_version
  oauth2_proxy_image_version = var.oauth2_proxy_image_version
  upstream_uri               = "http://${helm_release.headlamp.name}.${kubernetes_namespace_v1.k8s_dashboard.metadata[0].name}.svc.cluster.local:${local.headlamp_port}"
  session_redis              = var.session_redis

  depends_on = [helm_release.headlamp]
}

# Read-only cluster-scoped extras Headlamp needs (cluster overview, metrics,
# CRD discovery, storage). The aggregation label causes the kube-controller-
# manager to merge these rules into the built-in `view` ClusterRole, which the
# Headlamp ServiceAccount is bound to via the helm chart's
# clusterRoleBinding.create / clusterRoleName = "view" settings.
resource "kubernetes_cluster_role_v1" "headlamp_view_extras" {
  metadata {
    name = "headlamp-view-extras"
    labels = {
      "rbac.authorization.k8s.io/aggregate-to-view" = "true"
    }
  }

  rule {
    api_groups = [""]
    resources  = ["nodes", "persistentvolumes"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["apiextensions.k8s.io"]
    resources  = ["customresourcedefinitions"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["metrics.k8s.io"]
    resources  = ["nodes", "pods"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["storage.k8s.io"]
    resources  = ["storageclasses", "csidrivers", "csinodes", "volumeattachments"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubectl_manifest" "headlamp_ingressroute" {
  yaml_body = yamlencode({
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "headlamp"
      namespace = kubernetes_namespace_v1.k8s_dashboard.metadata[0].name
    }
    spec = {
      entryPoints = ["web"]
      routes = [
        {
          match = "Host(`${var.hostname}`)"
          kind  = "Rule"
          services = [{
            name = module.headlamp_oauth2_proxy.service_name
            port = 80
          }]
        },
      ]
    }
  })

  depends_on = [module.headlamp_oauth2_proxy]
}
