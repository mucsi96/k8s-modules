output "host" {
  description = "Public IPv4 address of the Hetzner server."
  value       = hcloud_server.this.ipv4_address
  depends_on  = [terraform_data.wait_for_cloud_init]
}

output "username" {
  description = "Non-root username created on the server."
  value       = var.username
}

output "initial_password" {
  description = "Initial password for the non-root user."
  value       = random_password.initial_password.result
  sensitive   = true
}

output "initial_port" {
  description = "Initial SSH port."
  value       = 22
}
