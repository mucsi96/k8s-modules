output "k8s_user_config" {
  value = module.create_film_namespace.k8s_user_config
}

output "film_api_client_id" {
  value = module.setup_film_api.client_id
}

output "film_api_client_secret" {
  value = module.setup_film_api.client_secret
}

output "film_spa_client_id" {
  value = module.setup_film_spa.client_id
}

output "film_api_resource_object_id" {
  value = module.setup_film_api.resource_object_id
}

output "film_api_roles_ids" {
  value = module.setup_film_api.roles_ids
}
