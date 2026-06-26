output "k8s_user_config" {
  value = module.app_base.k8s_user_config
}

output "party_api_client_id" {
  value = module.setup_party_api.client_id
}

output "party_api_client_secret" {
  value = module.setup_party_api.client_secret
}

output "party_spa_client_id" {
  value = module.setup_party_spa.client_id
}

output "party_api_resource_object_id" {
  value = module.setup_party_api.resource_object_id
}

output "party_api_roles_ids" {
  value = module.setup_party_api.roles_ids
}
