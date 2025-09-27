output "k8s_user_config" {
  value = module.create_backup_namespace.k8s_user_config
}

output "backup_api_client_id" {
  value = module.setup_backup_api.client_id
}

output "backup_spa_client_id" {
  value = module.setup_backup_spa.client_id
}

output "backup_api_resource_object_id" {
  value = module.setup_backup_api.resource_object_id
}

output "backup_api_roles_ids" {
  value = module.setup_backup_api.roles_ids
}

output "backup_cron_job_client_id" {
  value = module.setup_backup_cron_job.client_id
}

output "backup_cron_job_resource_object_id" {
  value = module.setup_backup_cron_job.resource_object_id
}
