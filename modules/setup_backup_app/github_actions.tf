module "app_base" {
  source = "../setup_app_base"

  github_repository    = "postgres-azure-backup"
  environment_name     = var.environment_name
  app_name             = "backup"
  azure_location       = var.azure_location
  tenant_id            = var.tenant_id
  owner                = var.owner
  twingate_service_key = var.twingate_service_key
  k8s_user_config      = module.create_backup_namespace.k8s_user_config
  app_hostname         = local.app_hostname
  api_client_id        = module.setup_backup_api.client_id
  api_client_secret    = module.setup_backup_api.client_secret
  spa_client_id        = module.setup_backup_spa.client_id
}
