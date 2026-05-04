resource "kubernetes_namespace_v1" "kubernetes_dashboard" {
  metadata {
    name = "kubernetes-dashboard"
  }
}

resource "helm_release" "kubernetes_dashboard" {
  name       = "kubernetes-dashboard"
  repository = "https://kubernetes.github.io/dashboard/"
  chart      = "kubernetes-dashboard"
  version    = var.kubernetes_dashboard_chart_version
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
    api = {
      containers = {
        args = [
          "--enable-skip-login",
          "--token-ttl=0",
        ]
      }
    }
    auth = {
      containers = {
        args = [
          "--enable-skip-login",
        ]
      }
    }
  })]

  depends_on = [var.wait_for]
}

resource "kubernetes_service_account_v1" "dashboard_admin" {
  metadata {
    name      = "dashboard-admin"
    namespace = kubernetes_namespace_v1.kubernetes_dashboard.metadata[0].name
  }
}

resource "kubernetes_cluster_role_binding_v1" "dashboard_admin" {
  metadata {
    name = "dashboard-admin"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.dashboard_admin.metadata[0].name
    namespace = kubernetes_namespace_v1.kubernetes_dashboard.metadata[0].name
  }
}

resource "kubernetes_secret_v1" "dashboard_admin_token" {
  metadata {
    name      = "dashboard-admin-token"
    namespace = kubernetes_namespace_v1.kubernetes_dashboard.metadata[0].name
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account_v1.dashboard_admin.metadata[0].name
    }
  }

  type                           = "kubernetes.io/service-account-token"
  wait_for_service_account_token = true
}
