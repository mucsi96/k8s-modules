resource "azurerm_key_vault_secret" "expense_tracker_db_url" {
  key_vault_id = module.app_base.key_vault_id
  name         = "db-url"
  value        = module.postgres_schema.jdbc_url
}

resource "azurerm_key_vault_secret" "expense_tracker_db_username" {
  key_vault_id = module.app_base.key_vault_id
  name         = "db-username"
  value        = module.postgres_schema.credentials.username
}

resource "azurerm_key_vault_secret" "expense_tracker_db_password" {
  key_vault_id = module.app_base.key_vault_id
  name         = "db-password"
  value        = module.postgres_schema.credentials.password
}

# Shared bearer token for the bank email notification endpoint. The
# Cloudflare Email Worker (setup_bank_email_worker) sends it in the
# Authorization header; the API reads this secret to validate it.
resource "random_password" "bank_notification_token" {
  length  = 64
  special = false
}

resource "azurerm_key_vault_secret" "expense_tracker_bank_notification_token" {
  key_vault_id = module.app_base.key_vault_id
  name         = "bank-notification-token"
  value        = random_password.bank_notification_token.result
}
