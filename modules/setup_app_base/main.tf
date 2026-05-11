module "create_namespace" {
  source                     = "../create_app_namespace"
  environment_name           = var.environment_name
  k8s_namespace              = var.app_name
  k8s_host                   = var.k8s_host
  k8s_cluster_ca_certificate = var.k8s_cluster_ca_certificate
}

# Combined per-app SP: reads the app's Key Vault (azurerm_role_assignment in
# secrets.tf) and deploys into the app's namespace (RoleBinding +
# ClusterRoleBinding below). Replaces the previous puller-only SP wired via
# register_github_oidc; AZURE_CLIENT_ID in the app's repo now points here.
module "github_deploy" {
  source = "../register_github_k8s_deploy"

  display_name   = "GitHub Actions deploy - ${var.environment_name} - ${var.app_name}"
  owner          = var.owner
  github_subject = "repo:${var.github_repository_owner}/${var.github_repository}:ref:refs/heads/main"
}

# Bind the deploy SP to the per-namespace Role created by create_app_namespace.
# Namespace and CRD reads are deliberately not granted — application charts
# don't manage either of those, so the matching ClusterRole is not bound here.
# Subject name is the SP's `oid` because the apiserver runs with
# --oidc-username-claim=oid --oidc-username-prefix=-.
resource "kubernetes_role_binding" "deploy" {
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
    name      = module.github_deploy.service_principal_object_id
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
