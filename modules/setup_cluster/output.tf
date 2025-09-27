output "resource_group_name" {
  value = var.azure_resource_group_name
}

output "location" {
  value = var.azure_location
}

output "owner" {
  value = data.azurerm_client_config.current.object_id
}

output "tenant_id" {
  value = data.azurerm_client_config.current.tenant_id
}

output "subscription_id" {
  value = data.azurerm_client_config.current.subscription_id
}

output "issuer" {
  value = "https://login.microsoftonline.com/${data.azurerm_client_config.current.tenant_id}/v2.0"
}

output "oidc_issuer_url" {
  value = azurerm_kubernetes_cluster.kubernetes_cluster.oidc_issuer_url
}

output "k8s_admin_config" {
  value     = azurerm_kubernetes_cluster.kubernetes_cluster.kube_config_raw
  sensitive = true
}

output "k8s_host" {
  value     = azurerm_kubernetes_cluster.kubernetes_cluster.kube_config.0.host
  sensitive = true
}

output "k8s_client_certificate" {
  value     = base64decode(azurerm_kubernetes_cluster.kubernetes_cluster.kube_config.0.client_certificate)
  sensitive = true
}

output "k8s_client_key" {
  value     = base64decode(azurerm_kubernetes_cluster.kubernetes_cluster.kube_config.0.client_key)
  sensitive = true
}

output "k8s_cluster_ca_certificate" {
  value     = base64decode(azurerm_kubernetes_cluster.kubernetes_cluster.kube_config.0.cluster_ca_certificate)
  sensitive = true
}
