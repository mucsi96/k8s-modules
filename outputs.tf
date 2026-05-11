output "hcloud_ipv4_address" {
  description = "Public IPv4 address of the cluster server. Authoritative source for scripts/ssh_to_server.sh; secrets.tf mirrors it to Key Vault for tooling that cannot read Terraform state."
  value       = module.provision_hetzner_server.ipv4_address
}

output "hcloud_ssh_port" {
  description = "Custom SSH port baked into the cloud-init sshd drop-in."
  value       = module.provision_hetzner_server.ssh_port
}

output "hcloud_ssh_user" {
  description = "Sudo user created via cloud-init."
  value       = module.provision_hetzner_server.username
}

output "hcloud_ssh_private_key" {
  description = "Generated OpenSSH private key. Sensitive; consume via `terraform output -raw hcloud_ssh_private_key | ssh-add -`."
  value       = module.provision_hetzner_server.ssh_private_key
  sensitive   = true
}

output "apiserver_oidc_client_id" {
  description = "Entra application client_id for the Kubernetes API server. Used as kube-apiserver --oidc-client-id and as the kubelogin --server-id baked into each app's k8s-config kubeconfig."
  value       = module.setup_cluster.apiserver_oidc_client_id
}
