output "ssh_public_key" {
  description = "Public SSH key in OpenSSH format generated for the provided user."
  value       = tls_private_key.user.public_key_openssh
}

output "ssh_private_key" {
  description = "Private SSH key in OpenSSH format generated for the provided user."
  value       = tls_private_key.user.private_key_openssh
}

output "user_password" {
  description = "Randomly generated password for the provided user."
  value       = random_password.user_password.result
}
