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

resource "azurerm_key_vault_secret" "twingate_service_key" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "twingate-service-key"
  value        = module.setup_twingate.service_key
}

resource "azurerm_key_vault_secret" "hetzner_host" {
  count        = var.provision_with_hetzner ? 1 : 0
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "host"
  value        = module.provision_hetzner_server[0].ipv4_address
}

resource "azurerm_key_vault_secret" "hetzner_ssh_user_name" {
  count        = var.provision_with_hetzner ? 1 : 0
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "ssh-user-name"
  value        = module.provision_hetzner_server[0].username
}

resource "azurerm_key_vault_secret" "hetzner_ssh_initial_port" {
  count        = var.provision_with_hetzner ? 1 : 0
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "ssh-initial-port"
  value        = tostring(module.provision_hetzner_server[0].ssh_port)
}

resource "azurerm_key_vault_secret" "hetzner_ssh_initial_password" {
  count        = var.provision_with_hetzner ? 1 : 0
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "ssh-initial-password"
  value        = module.provision_hetzner_server[0].initial_password
}

