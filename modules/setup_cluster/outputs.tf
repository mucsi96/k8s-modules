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
  description = "Entra application client_id that kube-apiserver uses as --oidc-client-id. Pass to kubelogin as --server-id; matches the `aud` claim in tokens minted for the cluster."
  value       = local.apiserver_oidc_client_id
}

output "apiserver_oidc_issuer_url" {
  description = "Entra v2 issuer URL trusted by kube-apiserver (--oidc-issuer-url). Derived from azure_tenant_id; exposed so callers don't have to recompute it."
  value       = local.apiserver_oidc_issuer_url
}
