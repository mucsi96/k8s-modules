data "azurerm_key_vault" "kv" {
  name                = var.azure_key_vault_name
  resource_group_name = var.environment_name
}

data "azurerm_key_vault_secret" "k8s_config" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "k8s-config"
  depends_on   = [ansible_playbook.install_microk8s]
}

data "azurerm_key_vault_secret" "k8s_host" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "k8s-host"
  depends_on   = [ansible_playbook.install_microk8s]
}

data "azurerm_key_vault_secret" "k8s_client_certificate" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "k8s-client-certificate"
  depends_on   = [ansible_playbook.install_microk8s]
}

data "azurerm_key_vault_secret" "k8s_client_key" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "k8s-client-key"
  depends_on   = [ansible_playbook.install_microk8s]
}

data "azurerm_key_vault_secret" "k8s_cluster_ca_certificate" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "k8s-cluster-ca-certificate"
  depends_on   = [ansible_playbook.install_microk8s]
}

output "k8s_config" {
  description = "Admin kubeconfig pulled from the private server."
  value       = data.azurerm_key_vault_secret.k8s_config.value
  sensitive   = true
}

output "k8s_host" {
  description = "Kubernetes API server endpoint extracted from the admin kubeconfig."
  value       = data.azurerm_key_vault_secret.k8s_host.value
}

output "k8s_client_certificate" {
  description = "Client certificate for authenticating against the Kubernetes API server."
  value       = data.azurerm_key_vault_secret.k8s_client_certificate.value
  sensitive   = true
}

output "k8s_client_key" {
  description = "Client private key for authenticating against the Kubernetes API server."
  value       = data.azurerm_key_vault_secret.k8s_client_key.value
  sensitive   = true
}

output "k8s_cluster_ca_certificate" {
  description = "Cluster CA certificate used to verify the Kubernetes API server."
  value       = data.azurerm_key_vault_secret.k8s_cluster_ca_certificate.value
  sensitive   = true
}

output "oidc_issuer_url" {
  description = "Public issuer URL exposing the MicroK8s OIDC discovery document (workload-identity issuer for in-cluster pod tokens; NOT the Entra issuer that the apiserver trusts)."
  value       = data.azurerm_storage_account.oidc.primary_web_endpoint
  depends_on  = [ansible_playbook.publish_microk8s_oidc]
}

output "apiserver_oidc_client_id" {
  description = "Entra application client_id that kube-apiserver uses as --oidc-client-id. kubelogin passes this as --server-id so its access_tokens carry the right `aud`. Deliberately distinct from cluster_monitor_client_id so a leaked dashboard session can't be replayed against the apiserver."
  value       = local.apiserver_oidc_client_id
}

output "apiserver_oidc_issuer_url" {
  description = "Entra v2 issuer URL trusted by kube-apiserver (--oidc-issuer-url). Derived from azure_tenant_id; exposed so callers don't have to recompute it."
  value       = local.apiserver_oidc_issuer_url
}

output "cluster_monitor_client_id" {
  description = "Entra application client_id for the cluster monitor (Headlamp) dashboard. Wired into the dashboard's oauth2-proxy as its OIDC client_id. Not trusted by the apiserver — Headlamp talks to the apiserver as its own in-cluster ServiceAccount (bound to `view` by the helm chart)."
  value       = module.cluster_monitor.client_id
}

output "cluster_monitor_client_secret" {
  description = "Client secret paired with cluster_monitor_client_id; consumed by the dashboard's oauth2-proxy."
  value       = module.cluster_monitor.client_secret
  sensitive   = true
}

# Non-secret kubeconfig that delegates authentication to kubelogin. Exec block
# defaults to `azurecli` (humans run `az login` first); pipelines override at
# runtime by exporting AAD_LOGIN_METHOD=workloadidentity alongside the AZURE_*
# env vars set by azure/login@v3. Marked sensitive because it embeds the
# cluster CA cert (already a sensitive output of this module); the root stores
# it as the k8s-oidc-config Key Vault secret for scripts/pull_kube_oidc_config.sh.
output "k8s_oidc_config" {
  description = "Rendered kubelogin kubeconfig for humans (`az login`) and pipelines (AAD_LOGIN_METHOD=workloadidentity). Caller is expected to store this in Key Vault."
  value = yamlencode({
    apiVersion = "v1"
    kind       = "Config"
    clusters = [{
      name = var.environment_name
      cluster = {
        server                       = data.azurerm_key_vault_secret.k8s_host.value
        "certificate-authority-data" = base64encode(data.azurerm_key_vault_secret.k8s_cluster_ca_certificate.value)
      }
    }]
    contexts = [{
      name = var.environment_name
      context = {
        cluster = var.environment_name
        user    = var.environment_name
      }
    }]
    "current-context" = var.environment_name
    users = [{
      name = var.environment_name
      user = {
        exec = {
          apiVersion = "client.authentication.k8s.io/v1beta1"
          command    = "kubelogin"
          args = [
            "get-token",
            "--login=azurecli",
            "--server-id=${local.apiserver_oidc_client_id}",
            "--tenant-id=${var.azure_tenant_id}",
          ]
        }
      }
    }]
  })
  sensitive = true
}
