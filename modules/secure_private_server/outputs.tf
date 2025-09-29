output "ssh_public_key" {
  description = "Public SSH key in OpenSSH format generated for the provided user."
  value       = tls_private_key.user.public_key_openssh
}

output "ssh_private_key" {
  description = "Private SSH key in OpenSSH format generated for the provided user."
  value       = tls_private_key.user.private_key_openssh
}

output "ssh_port" {
  description = "Randomly selected SSH port."
  value       = random_integer.ssh_port.result
}
