resource "azurerm_key_vault_secret" "ssh_private_key" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "ssh-private-key"
  value        = module.setup_cluster.ssh_private_key
}

resource "azurerm_key_vault_secret" "ssh_port" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "ssh-port"
  value        = module.setup_cluster.ssh_port
}

resource "azurerm_key_vault_secret" "user_password" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "user-password"
  value        = module.setup_cluster.user_password
}


resource "azurerm_key_vault_secret" "issuer" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "issuer"
  value        = module.setup_cluster.oidc_issuer_url
}

resource "azurerm_key_vault_secret" "tenant_id" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "tenant-id"
  value        = data.azurerm_client_config.current.tenant_id
}

resource "azurerm_key_vault_secret" "k8s_admin_config" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "k8s-admin-config"
  value        = module.setup_cluster.k8s_config
}

resource "azurerm_key_vault_secret" "db_namespace_k8s_user_config" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "db-namespace-k8s-user-config"
  value        = module.create_database_namespace.k8s_user_config
}

resource "azurerm_key_vault_secret" "db_username" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "db-username"
  value        = module.create_database.username
}

resource "azurerm_key_vault_secret" "db_password" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "db-password"
  value        = module.create_database.password
}

/**
 * Backup App
 */
data "azurerm_key_vault" "backup_kv" {
  resource_group_name = var.environment_name
  name                = "${var.environment_name}-backup"
}

resource "azurerm_key_vault_secret" "backup_namespace_k8s_user_config" {
  key_vault_id = data.azurerm_key_vault.backup_kv.id
  name         = "k8s-config"
  value        = module.setup_backup_app.k8s_user_config
}

resource "azurerm_key_vault_secret" "backup_api_tenant_id" {
  key_vault_id = data.azurerm_key_vault.backup_kv.id
  name         = "tenant-id"
  value        = data.azurerm_client_config.current.tenant_id
}

resource "azurerm_key_vault_secret" "backup_api_client_id" {
  key_vault_id = data.azurerm_key_vault.backup_kv.id
  name         = "api-client-id"
  value        = module.setup_backup_app.backup_api_client_id
}

resource "azurerm_key_vault_secret" "backup_api_client_secret" {
  key_vault_id = data.azurerm_key_vault.backup_kv.id
  name         = "api-client-secret"
  value        = module.setup_backup_app.backup_api_client_secret
}

resource "azurerm_key_vault_secret" "backup_spa_client_id" {
  key_vault_id = data.azurerm_key_vault.backup_kv.id
  name         = "spa-client-id"
  value        = module.setup_backup_app.backup_spa_client_id
}

resource "azurerm_key_vault_secret" "backup_dbs_config" {
  key_vault_id = data.azurerm_key_vault.backup_kv.id
  name         = "dbs-config"
  value = jsonencode([
    {
      name            = "Learn language"
      host            = "postgres1.db"
      port            = 5432
      database        = "postgres1"
      schema          = "learn_language"
      username        = module.create_database.username
      password        = module.create_database.password
      createPlainDump = true
      folderBackups = [
        {
          path = "/app/storage/learn-language"
        }
      ]
    }
  ])
}

resource "azurerm_key_vault_secret" "backup_hostname" {
  key_vault_id = data.azurerm_key_vault.backup_kv.id
  name         = "hostname"
  value        = "backup.${data.azurerm_key_vault_secret.dns_zone.value}"
}

/**
 * Learn Language
 */
data "azurerm_key_vault" "learn_language_kv" {
  resource_group_name = var.environment_name
  name                = "${var.environment_name}-learn-language"
}

resource "azurerm_key_vault_secret" "learn_language_namespace_k8s_user_config" {
  key_vault_id = data.azurerm_key_vault.learn_language_kv.id
  name         = "k8s-config"
  value        = module.create_learn_language_namespace.k8s_user_config
}

resource "azurerm_key_vault_secret" "learn_language_tenant_id" {
  key_vault_id = data.azurerm_key_vault.learn_language_kv.id
  name         = "tenant-id"
  value        = data.azurerm_client_config.current.tenant_id
}

resource "azurerm_key_vault_secret" "learn_language_api_client_id" {
  key_vault_id = data.azurerm_key_vault.learn_language_kv.id
  name         = "api-client-id"
  value        = module.setup_learn_language_api.client_id
}

resource "azurerm_key_vault_secret" "learn_language_api_client_secret" {
  key_vault_id = data.azurerm_key_vault.learn_language_kv.id
  name         = "api-client-secret"
  value        = module.setup_learn_language_api.client_secret
}

resource "azurerm_key_vault_secret" "learn_language_spa_client_id" {
  key_vault_id = data.azurerm_key_vault.learn_language_kv.id
  name         = "spa-client-id"
  value        = module.setup_learn_language_spa.client_id
}

resource "azurerm_key_vault_secret" "learn_language_hostname" {
  key_vault_id = data.azurerm_key_vault.learn_language_kv.id
  name         = "hostname"
  value        = "language.${data.azurerm_key_vault_secret.dns_zone.value}"
}
