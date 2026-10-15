output "key_vault_id" {
  value      = azurerm_key_vault.app_kv.id
  depends_on = [azurerm_role_assignment.allow_owner_to_manage_kv]
}

output "namespace" {
  value = module.create_namespace.k8s_namespace
}
