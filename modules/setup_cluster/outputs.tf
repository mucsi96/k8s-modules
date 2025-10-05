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

output "user_password" {
  description = "Password for the provided user."
  value       = random_password.user_password.result
  sensitive   = true
}


locals {
  kube_admin_config_struct = yamldecode(data.local_file.kube_admin_config.content)
  k8s_cluster              = local.kube_admin_config_struct.clusters[0].cluster
  k8s_user                 = local.kube_admin_config_struct.users[0].user
}

output "k8s_config" {
  description = "Admin kubeconfig pulled from the private server."
  value       = data.local_file.kube_admin_config.content
  sensitive   = true
}

output "k8s_host" {
  description = "Kubernetes API server endpoint extracted from the admin kubeconfig."
  value       = local.k8s_cluster.server
}

output "k8s_client_certificate" {
  description = "Client certificate for authenticating against the Kubernetes API server."
  value       = base64decode(local.k8s_user["client-certificate-data"])
  sensitive   = true
}

output "k8s_client_key" {
  description = "Client private key for authenticating against the Kubernetes API server."
  value       = base64decode(local.k8s_user["client-key-data"])
  sensitive   = true
}

output "k8s_cluster_ca_certificate" {
  description = "Cluster CA certificate used to verify the Kubernetes API server."
  value       = base64decode(local.k8s_cluster["certificate-authority-data"])
  sensitive   = true
}
