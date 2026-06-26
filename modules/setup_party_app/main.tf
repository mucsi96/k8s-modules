locals {
  app_hostname = "party.${var.hostname}"
}

module "app_base" {
  source = "../setup_app_base"

  github_repository          = "party-app"
  environment_name           = var.environment_name
  app_name                   = "party"
  azure_location             = var.azure_location
  tenant_id                  = var.tenant_id
  azure_subscription_id      = var.azure_subscription_id
  owner                      = var.owner
  twingate_service_key       = var.twingate_service_key
  k8s_host                   = var.k8s_host
  k8s_cluster_ca_certificate = var.k8s_cluster_ca_certificate
  app_hostname               = local.app_hostname
  api_client_id              = module.setup_party_api.client_id
  api_client_secret          = module.setup_party_api.client_secret
  spa_client_id              = module.setup_party_spa.client_id
  api_resource_object_id     = module.setup_party_api.resource_object_id
  k8s_oidc_config            = var.k8s_oidc_config
  client_log_url             = var.client_log_url
}

module "setup_party_api" {
  source = "../register_api"
  owner  = var.owner

  display_name = "Party API"
  roles        = ["PartyReader", "PartyCreator"]
  scopes       = ["readParties", "createParty"]

  k8s_oidc_issuer_url           = var.k8s_oidc_issuer_url
  k8s_service_account_namespace = "party"
  k8s_service_account_name      = "party-api-workload-identity"
}

module "setup_party_spa" {
  source = "../register_spa"
  owner  = var.owner

  display_name  = "Party SPA"
  redirect_uris = ["https://${local.app_hostname}/", "http://localhost:4204/"]

  api_id        = module.setup_party_api.application_id
  api_client_id = module.setup_party_api.client_id
  api_scope_ids = [
    module.setup_party_api.scope_ids["readParties"],
    module.setup_party_api.scope_ids["createParty"]
  ]
}
