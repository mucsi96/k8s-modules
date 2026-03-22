output "k8s_user_config" {
  value = module.app_base.k8s_user_config
}

output "training_log_api_client_id" {
  value = module.setup_training_log_api.client_id
}

output "training_log_api_client_secret" {
  value = module.setup_training_log_api.client_secret
}

output "training_log_spa_client_id" {
  value = module.setup_training_log_spa.client_id
}

output "training_log_api_resource_object_id" {
  value = module.setup_training_log_api.resource_object_id
}

output "training_log_api_roles_ids" {
  value = module.setup_training_log_api.roles_ids
}
