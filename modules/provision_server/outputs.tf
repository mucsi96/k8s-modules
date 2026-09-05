output "ipv4_address" {
  description = "Primary public IPv4 address of the Netcup RS."
  value       = local.server.ipv4Addresses[0].ip
}

output "ipv6_address" {
  description = "Primary public IPv6 network prefix of the Netcup RS, or null when none is assigned."
  value       = try(local.server.ipv6Addresses[0].networkPrefix, null)
}

output "username" {
  description = "Passwordless sudo user created during Debian installation."
  value       = var.username
}

output "ssh_port" {
  description = "Custom SSH port configured by the Netcup installation script."
  value       = random_integer.ssh_port.result
}

output "ssh_private_key" {
  description = "Generated SSH private key in OpenSSH format."
  value       = tls_private_key.user.private_key_openssh
  sensitive   = true
}

output "ssh_public_key" {
  description = "Generated SSH public key registered with SCP and installed on the server."
  value       = tls_private_key.user.public_key_openssh
}

output "agent_loaded" {
  description = "Sentinel that lets downstream modules wait until the SSH key is loaded in ssh-agent."
  value       = terraform_data.ssh_agent_loaded.id
}

output "ssh_ready" {
  description = "Sentinel produced after the Debian bootstrap marker is reachable through Twingate SSH."
  value       = terraform_data.ssh_ready.id
}

output "server_id" {
  description = "Netcup SCP server ID."
  value       = var.netcup_server_id
}

output "netcup_refresh_token" {
  description = "Current SCP OAuth2 refresh token. Persist this in the caller's secret store after each apply."
  value       = local.netcup_refresh_token
  sensitive   = true
}
