module "create_backup_namespace" {
  source                    = "../create_app_namespace"
  azure_resource_group_name = var.azure_resource_group_name
  k8s_namespace             = "backup"
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
  redirect_uris = ["https://backup.${var.hostname}/", "http://localhost:4200/"]

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

module "setup_backup_cron_job" {
  source = "../register_job"
  owner  = var.owner

  display_name = "Backup Cron Job"

  api_id        = module.setup_backup_api.application_id
  api_client_id = module.setup_backup_api.client_id
  api_scope_ids = [
    module.setup_backup_api.scope_ids["createBackup"],
    module.setup_backup_api.scope_ids["cleanupBackups"],
  ]
  api_role_ids = [
    module.setup_backup_api.roles_ids["DatabaseBackupCreator"],
    module.setup_backup_api.roles_ids["DatabaseBackupCleaner"],
  ]

  k8s_oidc_issuer_url           = var.k8s_oidc_issuer_url
  k8s_service_account_namespace = "backup"
  k8s_service_account_name      = "postgres-azure-backup-cron-job-workload-identity"
}
