resource "azurerm_key_vault_secret" "user_password" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "user-password"
  value        = module.secure_private_server.user_password
}

resource "azurerm_key_vault_secret" "ssh_private_key" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "ssh-private-key"
  value        = module.secure_private_server.ssh_private_key
}

resource "azurerm_key_vault_secret" "ssh_public_key" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "ssh-public-key"
  value        = module.secure_private_server.ssh_public_key
}

# resource "azurerm_key_vault_secret" "issuer" {
#   key_vault_id = data.azurerm_key_vault.kv.id
#   name         = "issuer"
#   value        = module.setup_cluster.issuer
# }

# resource "azurerm_key_vault_secret" "tenant_id" {
#   key_vault_id = data.azurerm_key_vault.kv.id
#   name         = "tenant-id"
#   value        = module.setup_cluster.tenant_id
# }

# resource "azurerm_key_vault_secret" "k8s_admin_config" {
#   key_vault_id = data.azurerm_key_vault.kv.id
#   name         = "k8s-admin-config"
#   value        = module.setup_cluster.k8s_admin_config
# }

# resource "azurerm_key_vault_secret" "hostname" {
#   key_vault_id = data.azurerm_key_vault.kv.id
#   name         = "hostname"
#   value        = module.setup_ingress_controller.hostname
# }

# resource "azurerm_key_vault_secret" "db_namespace_k8s_user_config" {
#   key_vault_id = data.azurerm_key_vault.kv.id
#   name         = "db-namespace-k8s-user-config"
#   value        = module.create_database_namespace.k8s_user_config
# }

# resource "azurerm_key_vault_secret" "db_username" {
#   key_vault_id = data.azurerm_key_vault.kv.id
#   name         = "db-username"
#   value        = module.create_database.username
# }

# resource "azurerm_key_vault_secret" "db_password" {
#   key_vault_id = data.azurerm_key_vault.kv.id
#   name         = "db-password"
#   value        = module.create_database.password
# }

# /**
#  * Backup App
#  */
# resource "azurerm_key_vault_secret" "backup_namespace_k8s_user_config" {
#   key_vault_id = data.azurerm_key_vault.kv.id
#   name         = "backup-namespace-k8s-user-config"
#   value        = module.setup_backup_app.k8s_user_config
# }

# resource "azurerm_key_vault_secret" "backup_api_client_id" {
#   key_vault_id = data.azurerm_key_vault.kv.id
#   name         = "backup-api-client-id"
#   value        = module.setup_backup_app.backup_api_client_id
# }

# resource "azurerm_key_vault_secret" "backup_spa_client_id" {
#   key_vault_id = data.azurerm_key_vault.kv.id
#   name         = "backup-spa-client-id"
#   value        = module.setup_backup_app.backup_spa_client_id
# }

# resource "azurerm_key_vault_secret" "backup_cron_job_client_id" {
#   key_vault_id = data.azurerm_key_vault.kv.id
#   name         = "backup-cron-job-client-id"
#   value        = module.setup_backup_app.backup_cron_job_client_id
# }


# /**
#  * Learn Language
#  */

# resource "azurerm_key_vault_secret" "learn_language_namespace_k8s_user_config" {
#   key_vault_id = data.azurerm_key_vault.kv.id
#   name         = "learn-language-namespace-k8s-user-config"
#   value        = module.create_learn_language_namespace.k8s_user_config
# }

# resource "azuread_application_password" "learn_language_api_password" {
#   application_id = module.setup_learn_language_api.application_id
# }

# resource "azurerm_key_vault_secret" "learn_language_api_client_id" {
#   key_vault_id = data.azurerm_key_vault.kv.id
#   name         = "learn-language-api-client-id"
#   value        = module.setup_learn_language_api.client_id
# }

# resource "azurerm_key_vault_secret" "learn_language_api_client_secret" {
#   key_vault_id = data.azurerm_key_vault.kv.id
#   name         = "learn-language-api-client-secret"
#   value        = azuread_application_password.learn_language_api_password.value
# }

# resource "azurerm_key_vault_secret" "learn_language_spa_client_id" {
#   key_vault_id = data.azurerm_key_vault.kv.id
#   name         = "learn-language-spa-client-id"
#   value        = module.setup_learn_language_spa.client_id
# }

