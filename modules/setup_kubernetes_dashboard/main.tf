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
  })]

  depends_on = [var.wait_for]
}

resource "kubernetes_service_account_v1" "dashboard_viewer" {
  metadata {
    name      = "dashboard-viewer"
    namespace = kubernetes_namespace_v1.kubernetes_dashboard.metadata[0].name
  }
}

resource "kubernetes_cluster_role_v1" "dashboard_viewer" {
  metadata {
    name = "dashboard-viewer"
  }

  rule {
    api_groups = ["*"]
    resources  = ["*"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    non_resource_urls = ["*"]
    verbs             = ["get"]
  }
}

resource "kubernetes_cluster_role_binding_v1" "dashboard_viewer" {
  metadata {
    name = "dashboard-viewer"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.dashboard_viewer.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.dashboard_viewer.metadata[0].name
    namespace = kubernetes_namespace_v1.kubernetes_dashboard.metadata[0].name
  }
}

resource "kubernetes_secret_v1" "dashboard_viewer_token" {
  metadata {
    name      = "dashboard-viewer-token"
    namespace = kubernetes_namespace_v1.kubernetes_dashboard.metadata[0].name
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account_v1.dashboard_viewer.metadata[0].name
    }
  }

  type                           = "kubernetes.io/service-account-token"
  wait_for_service_account_token = true
}
