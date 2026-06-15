output "remote_network_id" {
  description = "Twingate remote network ID for the home cluster. Consumed by setup_twingate_access for its resources."
  value       = twingate_remote_network.home_cluster.id
}

output "access_token" {
  description = "Host connector access token. Baked into the server's cloud-init user_data."
  value       = twingate_connector_tokens.host.access_token
  sensitive   = true
}

output "refresh_token" {
  description = "Host connector refresh token. Baked into the server's cloud-init user_data."
  value       = twingate_connector_tokens.host.refresh_token
  sensitive   = true
}
