module "create_namespace" {
  source                     = "../create_app_namespace"
  environment_name           = var.environment_name
  k8s_namespace              = var.app_name
  k8s_host                   = var.k8s_host
  k8s_cluster_ca_certificate = var.k8s_cluster_ca_certificate
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

# Kubeconfig that delegates to kubelogin; published to the app KV as `k8s-config`
# and to the app repo as the `K8S_CONFIG` GitHub Actions secret. No bearer
# secret embedded — the deploy SP gets its token at runtime via kubelogin
# (azurecli mode, fed by azure/login@v3).
locals {
  k8s_kubelogin_config = yamlencode({
    apiVersion = "v1"
    kind       = "Config"
    clusters = [{
      name = "cluster"
      cluster = {
        server                       = var.k8s_host
        "certificate-authority-data" = base64encode(var.k8s_cluster_ca_certificate)
      }
    }]
    contexts = [{
      name = "default"
      context = {
        cluster   = "cluster"
        user      = "user"
        namespace = var.app_name
      }
    }]
    "current-context" = "default"
    users = [{
      name = "user"
      user = {
        exec = {
          apiVersion = "client.authentication.k8s.io/v1beta1"
          command    = "kubelogin"
          args = [
            "get-token",
            "--login=azurecli",
            "--server-id=${var.apiserver_client_id}",
            "--tenant-id=${var.tenant_id}",
          ]
        }
      }
    }]
  })
}
