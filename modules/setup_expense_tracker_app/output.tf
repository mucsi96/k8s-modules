output "k8s_user_config" {
  value = module.app_base.k8s_user_config
}

output "expense_tracker_api_client_id" {
  value = module.setup_expense_tracker_api.client_id
}

output "expense_tracker_api_client_secret" {
  value = module.setup_expense_tracker_api.client_secret
}

output "expense_tracker_spa_client_id" {
  value = module.setup_expense_tracker_spa.client_id
}

output "expense_tracker_api_resource_object_id" {
  value = module.setup_expense_tracker_api.resource_object_id
}

output "expense_tracker_api_roles_ids" {
  value = module.setup_expense_tracker_api.roles_ids
}
