resource "azurerm_key_vault" "app_kv" {
  resource_group_name        = var.environment_name
  name                       = "${var.environment_name}-${var.app_name}"
  location                   = var.azure_location
  tenant_id                  = var.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
}

resource "azurerm_role_assignment" "allow_owner_to_manage_kv" {
  scope                = azurerm_key_vault.app_kv.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = var.owner
}

resource "azurerm_role_assignment" "allow_api_to_read_kv" {
  scope                = azurerm_key_vault.app_kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.api_resource_object_id
}

resource "azurerm_key_vault_secret" "k8s_user_config" {
  key_vault_id = azurerm_key_vault.app_kv.id
  name         = "k8s-config"
  value        = module.create_namespace.k8s_user_config
  depends_on   = [azurerm_role_assignment.allow_owner_to_manage_kv]
}

resource "azurerm_key_vault_secret" "tenant_id" {
  key_vault_id = azurerm_key_vault.app_kv.id
  name         = "tenant-id"
  value        = var.tenant_id
  depends_on   = [azurerm_role_assignment.allow_owner_to_manage_kv]
}

resource "azurerm_key_vault_secret" "api_client_id" {
  key_vault_id = azurerm_key_vault.app_kv.id
  name         = "api-client-id"
  value        = var.api_client_id
  depends_on   = [azurerm_role_assignment.allow_owner_to_manage_kv]
}

resource "azurerm_key_vault_secret" "api_client_secret" {
  key_vault_id = azurerm_key_vault.app_kv.id
  name         = "api-client-secret"
  value        = var.api_client_secret
  depends_on   = [azurerm_role_assignment.allow_owner_to_manage_kv]
}

resource "azurerm_key_vault_secret" "spa_client_id" {
  key_vault_id = azurerm_key_vault.app_kv.id
  name         = "spa-client-id"
  value        = var.spa_client_id
  depends_on   = [azurerm_role_assignment.allow_owner_to_manage_kv]
}

resource "azurerm_key_vault_secret" "hostname" {
  key_vault_id = azurerm_key_vault.app_kv.id
  name         = "hostname"
  value        = var.app_hostname
  depends_on   = [azurerm_role_assignment.allow_owner_to_manage_kv]
}

resource "azurerm_key_vault_secret" "twingate_service_key" {
  count        = var.twingate_service_key == null ? 0 : 1
  key_vault_id = azurerm_key_vault.app_kv.id
  name         = "twingate-service-key"
  value        = var.twingate_service_key
  depends_on   = [azurerm_role_assignment.allow_owner_to_manage_kv]
}
