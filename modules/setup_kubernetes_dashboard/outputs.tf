output "dashboard_url" {
  description = "Public URL of the Kubernetes Dashboard"
  value       = "https://${local.app_hostname}"
}

output "client_id" {
  description = "Entra ID application client ID used by oauth2-proxy"
  value       = module.oauth2_proxy.client_id
}
