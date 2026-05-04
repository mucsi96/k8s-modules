locals {
  app_namespace = "kubernetes-dashboard"
  app_hostname  = "k8s-dashboard.${var.hostname}"
}

resource "kubernetes_namespace_v1" "kubernetes_dashboard" {
  metadata {
    name = local.app_namespace
  }
}

resource "kubernetes_service_account_v1" "dashboard_user" {
  metadata {
    name      = "kubernetes-dashboard-user"
    namespace = kubernetes_namespace_v1.kubernetes_dashboard.metadata[0].name
  }
}

resource "kubernetes_cluster_role_binding_v1" "dashboard_user" {
  metadata {
    name = "kubernetes-dashboard-user"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.dashboard_user.metadata[0].name
    namespace = kubernetes_namespace_v1.kubernetes_dashboard.metadata[0].name
  }

  role_ref {
    kind      = "ClusterRole"
    name      = "cluster-admin"
    api_group = "rbac.authorization.k8s.io"
  }
}

resource "kubernetes_secret_v1" "dashboard_user_token" {
  metadata {
    name      = "kubernetes-dashboard-user-token"
    namespace = kubernetes_namespace_v1.kubernetes_dashboard.metadata[0].name
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account_v1.dashboard_user.metadata[0].name
    }
  }

  type                           = "kubernetes.io/service-account-token"
  wait_for_service_account_token = true
}

resource "helm_release" "kubernetes_dashboard" {
  name       = "kubernetes-dashboard"
  repository = "https://kubernetes.github.io/dashboard/"
  chart      = "kubernetes-dashboard"
  version    = var.dashboard_chart_version
  namespace  = kubernetes_namespace_v1.kubernetes_dashboard.metadata[0].name
  wait       = true
  timeout    = 600

  # https://github.com/kubernetes/dashboard/blob/master/charts/kubernetes-dashboard/values.yaml
  values = [yamlencode({
    app = {
      ingress = {
        enabled = false
      }
    }
    kong = {
      proxy = {
        http = {
          enabled = true
        }
      }
    }
  })]
}

resource "helm_release" "kubernetes_dashboard_routes" {
  name      = "kubernetes-dashboard-routes"
  chart     = "${path.module}/charts/dashboard-routes"
  namespace = kubernetes_namespace_v1.kubernetes_dashboard.metadata[0].name

  values = [yamlencode({
    host                = local.app_hostname
    ssoNamespace        = var.sso_namespace
    ssoServiceName      = var.sso_service_name
    ssoServicePort      = var.sso_service_port
    serviceAccountToken = kubernetes_secret_v1.dashboard_user_token.data["token"]
  })]

  depends_on = [helm_release.kubernetes_dashboard]
}
