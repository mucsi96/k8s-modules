module "create_namespace" {
  source        = "../create_app_namespace"
  k8s_namespace = var.app_name
}

# Bind the deploy SP (github_deploy.tf) to the per-namespace Role created by
# create_app_namespace. Namespace and CRD reads are deliberately not granted —
# application charts don't manage either of those, so the matching ClusterRole
# is not bound here. Subject name is the SP's `oid` because the apiserver runs
# with --oidc-username-claim=oid --oidc-username-prefix=-.
resource "kubernetes_role_binding_v1" "deploy" {
  metadata {
    name      = "${var.app_name}-deploy"
    namespace = module.create_namespace.k8s_namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = var.app_name
  }

  subject {
    kind      = "User"
    name      = azuread_service_principal.github_deploy.object_id
    api_group = "rbac.authorization.k8s.io"
  }
}
