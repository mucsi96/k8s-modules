output "public_ip_address" {
  description = "Public IP address assigned to the testing virtual machine."
  value       = hcloud_server.vm.ipv4_address
}

output "admin_username" {
  description = "SSH username configured on the testing virtual machine."
  value       = var.ssh_user
}

output "admin_password" {
  description = "Administrator password generated for the testing virtual machine."
  value       = random_password.admin.result
  sensitive   = true
}

output "ssh_port" {
  description = "SSH port exposed on the testing virtual machine."
  value       = 22
}
