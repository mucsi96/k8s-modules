output "dashboard_url" {
  description = "Public URL of the Kubernetes Dashboard"
  value       = "https://${local.app_hostname}"
}
