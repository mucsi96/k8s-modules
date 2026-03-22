output "key_vault_id" {
  value = azurerm_key_vault.app_kv.id
}

output "k8s_user_config" {
  value     = module.create_namespace.k8s_user_config
  sensitive = true
}
