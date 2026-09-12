resource "random_password" "recipe_email_token" {
  length  = 64
  special = false
}

resource "azurerm_key_vault_secret" "cooking_recipe_email_token" {
  key_vault_id = module.app_base.key_vault_id
  name         = "recipe-email-token"
  value        = random_password.recipe_email_token.result
}

resource "azurerm_key_vault_secret" "cooking_db_url" {
  key_vault_id = module.app_base.key_vault_id
  name         = "db-url"
  value        = module.postgres_schema.jdbc_url
}

resource "azurerm_key_vault_secret" "cooking_db_username" {
  key_vault_id = module.app_base.key_vault_id
  name         = "db-username"
  value        = module.postgres_schema.credentials.username
}

resource "azurerm_key_vault_secret" "cooking_db_password" {
  key_vault_id = module.app_base.key_vault_id
  name         = "db-password"
  value        = module.postgres_schema.credentials.password
}
