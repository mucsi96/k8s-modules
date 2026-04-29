output "ipv4_address" {
  description = "Public IPv4 address of the provisioned Hetzner Cloud server."
  value       = hcloud_server.this.ipv4_address
}

output "ipv6_address" {
  description = "Public IPv6 address of the provisioned Hetzner Cloud server."
  value       = hcloud_server.this.ipv6_address
}

output "username" {
  description = "Initial sudo user name created via cloud-init."
  value       = var.username
}

output "initial_password" {
  description = "Random password set for the initial sudo user via cloud-init."
  value       = random_password.initial.result
  sensitive   = true
}

output "ssh_port" {
  description = "Initial SSH port exposed by the Hetzner Cloud image (always 22)."
  value       = 22
}

output "server_id" {
  description = "Hetzner Cloud server ID."
  value       = hcloud_server.this.id
}
