resource "kubernetes_service_account_v1" "cluster_admin" {
  metadata {
    name      = "cluster-admin"
    namespace = kubernetes_namespace_v1.auth.metadata[0].name
  }
}

resource "kubernetes_cluster_role_binding_v1" "cluster_admin" {
  metadata {
    name = "auth-cluster-admin"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.cluster_admin.metadata[0].name
    namespace = kubernetes_service_account_v1.cluster_admin.metadata[0].namespace
  }
}

resource "kubernetes_secret_v1" "cluster_admin_token" {
  metadata {
    name      = "cluster-admin-token"
    namespace = kubernetes_namespace_v1.auth.metadata[0].name
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account_v1.cluster_admin.metadata[0].name
    }
  }

  type                           = "kubernetes.io/service-account-token"
  wait_for_service_account_token = true
}
