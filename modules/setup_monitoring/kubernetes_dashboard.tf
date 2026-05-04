resource "helm_release" "kubernetes_dashboard" {
  name       = "kubernetes-dashboard"
  repository = "https://kubernetes.github.io/dashboard"
  chart      = "kubernetes-dashboard"
  version    = var.kubernetes_dashboard_chart_version
  namespace  = kubernetes_namespace_v1.monitoring.metadata[0].name
  wait       = true
  timeout    = 600

  # https://github.com/kubernetes/dashboard/blob/master/charts/kubernetes-dashboard/values.yaml
  values = [yamlencode({
    app = {
      ingress = {
        enabled = false
      }
    }
    # Auto-login via the Bearer token injected by the Traefik middleware below.
    auth = {
      role = "proxy"
    }
    metricsScraper = {
      enabled = true
    }
  })]
}

resource "kubernetes_service_account_v1" "kubernetes_dashboard_admin" {
  metadata {
    name      = "kubernetes-dashboard-admin"
    namespace = kubernetes_namespace_v1.monitoring.metadata[0].name
  }
}

resource "kubernetes_cluster_role_binding_v1" "kubernetes_dashboard_admin" {
  metadata {
    name = "kubernetes-dashboard-admin"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.kubernetes_dashboard_admin.metadata[0].name
    namespace = kubernetes_namespace_v1.monitoring.metadata[0].name
  }
}

resource "kubernetes_secret_v1" "kubernetes_dashboard_admin_token" {
  metadata {
    name      = "kubernetes-dashboard-admin-token"
    namespace = kubernetes_namespace_v1.monitoring.metadata[0].name
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account_v1.kubernetes_dashboard_admin.metadata[0].name
    }
  }

  type                           = "kubernetes.io/service-account-token"
  wait_for_service_account_token = true
}
