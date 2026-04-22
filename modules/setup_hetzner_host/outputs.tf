output "host" {
  description = "Public IPv4 address of the Hetzner server."
  value       = hcloud_server.this.ipv4_address
}

output "username" {
  description = "Bootstrap SSH username for first connection."
  value       = var.ssh_username
}

output "initial_password" {
  description = "Bootstrap SSH password for first connection."
  value       = random_password.bootstrap.result
  sensitive   = true
}

output "initial_port" {
  description = "Bootstrap SSH port for first connection."
  value       = var.ssh_initial_port
}

output "bootstrap_private_key" {
  description = "Private SSH key used to register the Hetzner key pair."
  value       = tls_private_key.bootstrap.private_key_openssh
  sensitive   = true
}
