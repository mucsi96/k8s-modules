output "k8s_user_config" {
  value = module.app_base.k8s_user_config
}

output "hello_api_client_id" {
  value = module.setup_hello_api.client_id
}

output "hello_api_client_secret" {
  value = module.setup_hello_api.client_secret
}

output "hello_spa_client_id" {
  value = module.setup_hello_spa.client_id
}

output "hello_api_resource_object_id" {
  value = module.setup_hello_api.resource_object_id
}

output "hello_api_roles_ids" {
  value = module.setup_hello_api.roles_ids
}
