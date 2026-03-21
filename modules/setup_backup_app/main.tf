locals {
  app_hostname = "backup.${var.hostname}"
}

module "create_backup_namespace" {
  source                     = "../create_app_namespace"
  environment_name           = var.environment_name
  k8s_namespace              = "backup"
  k8s_host                   = var.k8s_host
  k8s_cluster_ca_certificate = var.k8s_cluster_ca_certificate
}

module "setup_backup_api" {
  source = "../register_api"
  owner  = var.owner

  display_name = "Backup API"
  roles        = ["DatabaseBackupsReader", "DatabaseBackupCreator", "DatabaseBackupCleaner", "DatabaseBackupRestorer", "DatabaseBackupDownloader"]
  scopes       = ["readBackups", "createBackup", "cleanupBackups", "restoreBackup", "downloadBackup"]

  k8s_oidc_issuer_url           = var.k8s_oidc_issuer_url
  k8s_service_account_namespace = "backup"
  k8s_service_account_name      = "postgres-azure-backup-api-workload-identity"
}

module "setup_backup_spa" {
  source = "../register_spa"
  owner  = var.owner

  display_name  = "Backup SPA"
  redirect_uris = ["https://${local.app_hostname}/", "http://localhost:4200/"]

  api_id        = module.setup_backup_api.application_id
  api_client_id = module.setup_backup_api.client_id
  api_scope_ids = [
    module.setup_backup_api.scope_ids["readBackups"],
    module.setup_backup_api.scope_ids["createBackup"],
    module.setup_backup_api.scope_ids["cleanupBackups"],
    module.setup_backup_api.scope_ids["restoreBackup"],
    module.setup_backup_api.scope_ids["downloadBackup"]
  ]
}

data "azurerm_storage_account" "storage_account" {
  name                = var.azure_storage_account_name
  resource_group_name = var.azure_storage_account_resource_group_name
}

data "azurerm_storage_container" "backups_storage_container" {
  name               = "backups"
  storage_account_id = data.azurerm_storage_account.storage_account.id
}
