output "k8s_user_config" {
  value = module.create_learn_language_namespace.k8s_user_config
}

output "learn_language_api_client_id" {
  value = module.setup_learn_language_api.client_id
}

output "learn_language_api_client_secret" {
  value = module.setup_learn_language_api.client_secret
}

output "learn_language_spa_client_id" {
  value = module.setup_learn_language_spa.client_id
}

output "learn_language_api_resource_object_id" {
  value = module.setup_learn_language_api.resource_object_id
}

output "learn_language_api_roles_ids" {
  value = module.setup_learn_language_api.roles_ids
}
