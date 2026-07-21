resource "azurerm_key_vault_secret" "learn_language_db_url" {
  key_vault_id = module.app_base.key_vault_id
  name         = "db-url"
  value        = var.db_jdbc_url
}

resource "azurerm_key_vault_secret" "learn_language_db_username" {
  key_vault_id = module.app_base.key_vault_id
  name         = "db-username"
  value        = var.db_username
}

resource "azurerm_key_vault_secret" "learn_language_db_password" {
  key_vault_id = module.app_base.key_vault_id
  name         = "db-password"
  value        = var.db_password
}

resource "random_bytes" "learn_language_token_encryption_key" {
  length = 32
}

resource "azurerm_key_vault_secret" "learn_language_token_encryption_key" {
  key_vault_id = module.app_base.key_vault_id
  name         = "token-encryption-key"
  value        = random_bytes.learn_language_token_encryption_key.base64
}
