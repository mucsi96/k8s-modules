resource "azuread_app_role_assignment" "allow_admin_user_to_read_reading_tracker_books" {
  app_role_id         = module.setup_reading_tracker_api.roles_ids["BookReader"]
  principal_object_id = var.owner
  resource_object_id  = module.setup_reading_tracker_api.resource_object_id
}

resource "azuread_app_role_assignment" "allow_admin_user_to_create_reading_tracker_books" {
  app_role_id         = module.setup_reading_tracker_api.roles_ids["BookCreator"]
  principal_object_id = var.owner
  resource_object_id  = module.setup_reading_tracker_api.resource_object_id
}

resource "azurerm_role_assignment" "allow_reading_tracker_api_to_read_reading_tracker_kv" {
  scope                = azurerm_key_vault.reading_tracker_kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.setup_reading_tracker_api.resource_object_id
}
