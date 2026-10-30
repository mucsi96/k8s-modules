resource "azurerm_key_vault" "app" {
  resource_group_name        = var.environment_name
  name                       = "${var.environment_name}-${local.name}"
  location                   = var.azure_location
  tenant_id                  = var.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
}

resource "azurerm_role_assignment" "owner_vault" {
  scope                = azurerm_key_vault.app.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = var.owner
}

locals {
  deployment_config = {
    k8s-config            = var.k8s_oidc_config
    hostname              = var.hostname
    api-client-id         = module.setup_observatory_api.client_id
    forward-auth-config   = jsonencode(module.forward_auth.deployment_config)
    client-storage-config = jsonencode(module.client_storage.deployment_config)
  }
}

resource "azurerm_key_vault_secret" "deployment" {
  for_each     = nonsensitive(toset(keys(local.deployment_config)))
  key_vault_id = azurerm_key_vault.app.id
  name         = each.key
  value        = local.deployment_config[each.key]
  depends_on   = [azurerm_role_assignment.owner_vault]
}

resource "azurerm_role_assignment" "deploy_config" {
  for_each             = azurerm_key_vault_secret.deployment
  scope                = each.value.resource_versionless_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azuread_service_principal.github_deploy.object_id
}
