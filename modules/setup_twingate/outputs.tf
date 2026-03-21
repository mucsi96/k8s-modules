output "service_keys" {
  description = "Map of app name to Twingate service key for GitHub Actions"
  value       = { for name in var.app_names : name => twingate_service_account_key.app[name].token }
  sensitive   = true
}
