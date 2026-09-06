resource "azurerm_key_vault" "grafana" {
  name                       = "${var.environment_name}-grafana"
  resource_group_name        = var.environment_name
  location                   = var.azure_location
  tenant_id                  = var.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
}

resource "azurerm_role_assignment" "manage_grafana_vault" {
  scope                = azurerm_key_vault.grafana.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = var.owner
}

resource "azurerm_key_vault_secret" "grafana_db_password" {
  key_vault_id = azurerm_key_vault.grafana.id
  name         = "db-password"
  value        = module.postgres_schema.password
  depends_on   = [azurerm_role_assignment.manage_grafana_vault]
}
