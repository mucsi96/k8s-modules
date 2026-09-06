resource "azurerm_key_vault_secret" "training_log_db_url" {
  key_vault_id = module.app_base.key_vault_id
  name         = "db-url"
  value        = module.postgres_schema.jdbc_url
}

resource "azurerm_key_vault_secret" "training_log_db_username" {
  key_vault_id = module.app_base.key_vault_id
  name         = "db-username"
  value        = module.postgres_schema.credentials.username
}

resource "azurerm_key_vault_secret" "training_log_db_password" {
  key_vault_id = module.app_base.key_vault_id
  name         = "db-password"
  value        = module.postgres_schema.credentials.password
}

resource "random_bytes" "training_log_token_encryption_key" {
  length = 32
}

resource "azurerm_key_vault_secret" "training_log_token_encryption_key" {
  key_vault_id = module.app_base.key_vault_id
  name         = "token-encryption-key"
  value        = random_bytes.training_log_token_encryption_key.base64
}
