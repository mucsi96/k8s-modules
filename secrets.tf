# ── Local cluster secrets ────────────────────────────────────────────────────

resource "azurerm_key_vault_secret" "ssh_private_key" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "local-ssh-private-key"
  value        = module.setup_cluster.ssh_private_key
}

resource "azurerm_key_vault_secret" "ssh_port" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "local-ssh-port"
  value        = module.setup_cluster.ssh_port
}

resource "azurerm_key_vault_secret" "user_password" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "local-user-password"
  value        = module.setup_cluster.user_password
}

resource "azurerm_key_vault_secret" "issuer" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "local-issuer"
  value        = module.setup_cluster.oidc_issuer_url
}

resource "azurerm_key_vault_secret" "k8s_admin_config" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "local-k8s-admin-config"
  value        = module.setup_cluster.k8s_config
}

resource "azurerm_key_vault_secret" "db_namespace_k8s_user_config" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "local-db-namespace-k8s-user-config"
  value        = module.create_database_namespace.k8s_user_config
}

resource "azurerm_key_vault_secret" "db_username" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "local-db-username"
  value        = module.create_database.username
}

resource "azurerm_key_vault_secret" "db_password" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "local-db-password"
  value        = module.create_database.password
}

resource "azurerm_key_vault_secret" "twingate_service_key" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "local-twingate-service-key"
  value        = module.setup_twingate.service_key
}

resource "azurerm_key_vault_secret" "tenant_id" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "tenant-id"
  value        = data.azurerm_client_config.current.tenant_id
}

# ── Hetzner cluster secrets ─────────────────────────────────────────────────

resource "azurerm_key_vault_secret" "hetzner_ssh_private_key" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "hetzner-ssh-private-key"
  value        = module.setup_cluster_hetzner.ssh_private_key
}

resource "azurerm_key_vault_secret" "hetzner_ssh_port" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "hetzner-ssh-port"
  value        = module.setup_cluster_hetzner.ssh_port
}

resource "azurerm_key_vault_secret" "hetzner_user_password" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "hetzner-user-password"
  value        = module.setup_cluster_hetzner.user_password
}

resource "azurerm_key_vault_secret" "hetzner_issuer" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "hetzner-issuer"
  value        = module.setup_cluster_hetzner.oidc_issuer_url
}

resource "azurerm_key_vault_secret" "hetzner_k8s_admin_config" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "hetzner-k8s-admin-config"
  value        = module.setup_cluster_hetzner.k8s_config
}

resource "azurerm_key_vault_secret" "hetzner_db_namespace_k8s_user_config" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "hetzner-db-namespace-k8s-user-config"
  value        = module.create_database_namespace_hetzner.k8s_user_config
}

resource "azurerm_key_vault_secret" "hetzner_db_username" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "hetzner-db-username"
  value        = module.create_database_hetzner.username
}

resource "azurerm_key_vault_secret" "hetzner_db_password" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "hetzner-db-password"
  value        = module.create_database_hetzner.password
}

resource "azurerm_key_vault_secret" "hetzner_twingate_service_key" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "hetzner-twingate-service-key"
  value        = module.setup_twingate_hetzner.service_key
}
