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
  timeout    = 120

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

# oauth2-proxy gates who can open the dashboard and injects the user's
# id_token as Authorization: Bearer. Headlamp's backend forwards that token
# to the apiserver as the caller's identity; the in-cluster ServiceAccount
# bound by the helm chart's clusterRoleBinding is only a fallback that
# kicks in if no header is set.
#
# View-only RBAC is enforced at the apiserver, not here. The apiserver's
# structured-auth config (in setup_cluster) routes the dashboard's id_token
# — aud = cluster_monitor app — through a separate JWT authenticator that
# prefixes the username with "headlamp:". oidc_dashboard_view binds that
# prefixed username to `view`. So the operator's bare-oid cluster-admin
# binding from oidc_human_admin (which is what kubelogin tokens map to) is
# NOT inherited into Headlamp.
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

  inject_request_headers = [{
    name = "Authorization"
    values = [{
      claim  = "id_token"
      prefix = "Bearer "
    }]
  }]

  depends_on = [helm_release.headlamp]
}

# Read-only cluster-scoped extras the built-in `view` ClusterRole doesn't
# grant (nodes, persistent volumes, CRDs, metrics, storage classes). The
# aggregation label causes the kube-controller-manager to merge these rules
# into `view`, picked up by every subject bound to `view` — including the
# dashboard's headlamp:<oid> user (oidc_dashboard_view in setup_cluster) and
# the helm chart's Headlamp ServiceAccount.
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
