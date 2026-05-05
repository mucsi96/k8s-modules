output "service_name" {
  description = "Name of the oauth2-proxy in-cluster service (matches the Helm release name)"
  value       = helm_release.oauth2_proxy.name
}
