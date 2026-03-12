resource "azuread_app_role_assignment" "allow_admin_user_to_read_films" {
  app_role_id         = module.setup_film_api.roles_ids["FilmReader"]
  principal_object_id = var.owner
  resource_object_id  = module.setup_film_api.resource_object_id
}

resource "azuread_app_role_assignment" "allow_admin_user_to_create_films" {
  app_role_id         = module.setup_film_api.roles_ids["FilmCreator"]
  principal_object_id = var.owner
  resource_object_id  = module.setup_film_api.resource_object_id
}

resource "azurerm_role_assignment" "allow_film_api_to_read_film_kv" {
  scope                = azurerm_key_vault.film_kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.setup_film_api.resource_object_id
}

resource "azurerm_role_assignment" "allow_owner_to_manage_film_kv" {
  scope                = azurerm_key_vault.film_kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.owner
}
