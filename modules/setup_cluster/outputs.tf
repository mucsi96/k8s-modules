output "ssh_public_key" {
  description = "Public SSH key in OpenSSH format generated for the provided user."
  value       = tls_private_key.user.public_key_openssh
}

output "ssh_private_key" {
  description = "Private SSH key in OpenSSH format generated for the provided user."
  value       = tls_private_key.user.private_key_openssh
}

output "ssh_port" {
  description = "Randomly selected SSH port."
  value       = random_integer.ssh_port.result
}

output "user_password" {
  description = "Password for the provided user."
  value       = random_password.user_password.result
  sensitive   = true
}


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
