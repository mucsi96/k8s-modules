resource "azuread_app_role_assignment" "allow_admin_user_to_read_learn_language_card_decks" {
  app_role_id         = module.setup_learn_language_api.roles_ids["DeckReader"]
  principal_object_id = var.owner
  resource_object_id  = module.setup_learn_language_api.resource_object_id
}

resource "azuread_app_role_assignment" "allow_admin_user_to_create_learn_language_card_decks" {
  app_role_id         = module.setup_learn_language_api.roles_ids["DeckCreator"]
  principal_object_id = var.owner
  resource_object_id  = module.setup_learn_language_api.resource_object_id
}

resource "azurerm_role_assignment" "allow_learn_language_api_to_read_learn_language_kv" {
  scope                = module.app_base.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.setup_learn_language_api.resource_object_id
}
