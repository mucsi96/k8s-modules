resource "azuread_app_role_assignment" "allow_admin_user_to_read_training_log_workouts" {
  app_role_id         = module.setup_training_log_api.roles_ids["WorkoutReader"]
  principal_object_id = var.owner
  resource_object_id  = module.setup_training_log_api.resource_object_id
}

resource "azuread_app_role_assignment" "allow_admin_user_to_create_training_log_workouts" {
  app_role_id         = module.setup_training_log_api.roles_ids["WorkoutCreator"]
  principal_object_id = var.owner
  resource_object_id  = module.setup_training_log_api.resource_object_id
}

resource "azurerm_role_assignment" "allow_training_log_api_to_read_training_log_kv" {
  scope                = azurerm_key_vault.training_log_kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.setup_training_log_api.resource_object_id
}

resource "azurerm_role_assignment" "allow_owner_to_manage_training_log_kv" {
  scope                = azurerm_key_vault.training_log_kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.owner
}
