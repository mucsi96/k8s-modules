output "release_name" {
  description = "Name of the deployed oauth2-proxy Helm release (matches the in-cluster service name)"
  value       = helm_release.oauth2_proxy.name
}

output "client_id" {
  description = "Entra application client ID used by oauth2-proxy"
  value       = module.register_webapp.client_id
}
