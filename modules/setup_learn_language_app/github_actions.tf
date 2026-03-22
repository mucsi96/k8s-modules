module "app_base" {
  source = "../setup_app_base"

  github_repository    = "learn-language"
  environment_name     = var.environment_name
  app_name             = "learn-language"
  azure_location       = var.azure_location
  tenant_id            = var.tenant_id
  owner                = var.owner
  twingate_service_key = var.twingate_service_key
  k8s_user_config      = module.create_learn_language_namespace.k8s_user_config
  app_hostname         = local.app_hostname
  api_client_id        = module.setup_learn_language_api.client_id
  api_client_secret    = module.setup_learn_language_api.client_secret
  spa_client_id        = module.setup_learn_language_spa.client_id
}
