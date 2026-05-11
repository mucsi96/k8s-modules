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

# oauth2-proxy gates sign-in (Entra confidential client = cluster_monitor app)
# and forwards the resulting id_token to Headlamp as Authorization: Bearer.
# Headlamp passes that token straight to the apiserver, which trusts it
# because cluster_monitor's client_id == apiserver --oidc-client-id (set in
# setup_cluster). The Kubernetes user is derived from the token's `oid` claim
# (apiserver --oidc-username-claim=oid), so the same oidc_human_admin
# ClusterRoleBinding that grants the operator kubectl access also grants them
# access through Headlamp — no separate dashboard-user CRB is needed.
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

# Read-only cluster-scoped extras Headlamp's `view` permissions don't cover
# out of the box (nodes, persistent volumes, CRDs, metrics, storage classes).
# The aggregation label causes the kube-controller-manager to merge these
# rules into the built-in `view` ClusterRole, picked up by every subject
# bound to it — including operator users authenticating through Headlamp
# (whose oid maps to the cluster-admin binding) and any future read-only
# bindings keyed against `view`.
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
