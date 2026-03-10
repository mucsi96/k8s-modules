output "k8s_user_config" {
  value = module.create_reading_tracker_namespace.k8s_user_config
}

output "reading_tracker_api_client_id" {
  value = module.setup_reading_tracker_api.client_id
}

output "reading_tracker_api_client_secret" {
  value = module.setup_reading_tracker_api.client_secret
}

output "reading_tracker_spa_client_id" {
  value = module.setup_reading_tracker_spa.client_id
}

output "reading_tracker_api_resource_object_id" {
  value = module.setup_reading_tracker_api.resource_object_id
}

output "reading_tracker_api_roles_ids" {
  value = module.setup_reading_tracker_api.roles_ids
}
