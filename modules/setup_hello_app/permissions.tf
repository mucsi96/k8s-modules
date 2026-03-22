resource "azuread_app_role_assignment" "allow_admin_user_to_read_hello_greetings" {
  app_role_id         = module.setup_hello_api.roles_ids["GreetingReader"]
  principal_object_id = var.owner
  resource_object_id  = module.setup_hello_api.resource_object_id
}

resource "azuread_app_role_assignment" "allow_admin_user_to_create_hello_greetings" {
  app_role_id         = module.setup_hello_api.roles_ids["GreetingCreator"]
  principal_object_id = var.owner
  resource_object_id  = module.setup_hello_api.resource_object_id
}

resource "azurerm_role_assignment" "allow_hello_api_to_read_hello_kv" {
  scope                = module.app_base.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.setup_hello_api.resource_object_id
}

resource "azurerm_role_assignment" "allow_owner_to_manage_hello_kv" {
  scope                = module.app_base.key_vault_id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.owner
}
