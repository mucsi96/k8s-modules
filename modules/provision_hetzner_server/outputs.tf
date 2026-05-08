output "ipv4_address" {
  description = "Public IPv4 address of the provisioned Hetzner Cloud server."
  value       = hcloud_server.this.ipv4_address
}

output "ipv6_address" {
  description = "Public IPv6 address of the provisioned Hetzner Cloud server."
  value       = hcloud_server.this.ipv6_address
}

output "username" {
  description = "Sudo user created via cloud-init."
  value       = var.username
}

output "ssh_port" {
  description = "Custom SSH port baked into the cloud-init sshd drop-in."
  value       = random_integer.ssh_port.result
}

output "ssh_private_key" {
  description = "Generated SSH private key in OpenSSH format. Stored in Key Vault for ad-hoc operator SSH; the apply itself uses ssh-agent."
  value       = tls_private_key.user.private_key_openssh
  sensitive   = true
}

output "ssh_public_key" {
  description = "Generated SSH public key in OpenSSH format, installed via cloud-init."
  value       = tls_private_key.user.public_key_openssh
}

output "agent_loaded" {
  description = "Sentinel that lets downstream modules wait until the SSH key has been added to ssh-agent."
  value       = terraform_data.ssh_agent_loaded.id
}

output "server_id" {
  description = "Hetzner Cloud server ID."
  value       = hcloud_server.this.id
}
