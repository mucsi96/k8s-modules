output "k8s_user_config" {
  value = module.app_base.k8s_user_config
}

output "cooking_api_client_id" {
  value = module.setup_cooking_api.client_id
}

output "cooking_api_client_secret" {
  value = module.setup_cooking_api.client_secret
}

output "cooking_spa_client_id" {
  value = module.setup_cooking_spa.client_id
}

output "cooking_api_resource_object_id" {
  value = module.setup_cooking_api.resource_object_id
}

output "cooking_api_roles_ids" {
  value = module.setup_cooking_api.roles_ids
}
