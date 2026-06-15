output "service_key" {
  description = "Twingate service key for GitHub Actions. Store as TWINGATE_SERVICE_KEY secret in GitHub."
  value       = twingate_service_account_key.github_actions.token
  sensitive   = true
}

output "ssh_resource_id" {
  description = "Twingate SSH resource ID. Threaded into provision_hetzner_server's ssh_ready as an ordering barrier so the SSH resource exists before the keyscan poll runs over Twingate."
  value       = twingate_resource.ssh.id
}
