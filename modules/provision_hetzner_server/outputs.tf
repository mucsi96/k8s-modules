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
  description = "Generated SSH private key in OpenSSH format. The key is also written to ssh_private_key_path so Ansible can use it."
  value       = tls_private_key.user.private_key_openssh
  sensitive   = true
}

output "ssh_public_key" {
  description = "Generated SSH public key in OpenSSH format, installed via cloud-init."
  value       = tls_private_key.user.public_key_openssh
}

output "ssh_private_key_path" {
  description = "Local path to the generated SSH private key file. Stable across applies; consumed by setup_cluster's Ansible playbooks."
  value       = terraform_data.user_private_key.input
}

output "known_hosts_ready" {
  description = "Sentinel that lets downstream modules wait until the host has been added to the local known_hosts file."
  value       = terraform_data.known_hosts_entry.id
}

output "server_id" {
  description = "Hetzner Cloud server ID."
  value       = hcloud_server.this.id
}
