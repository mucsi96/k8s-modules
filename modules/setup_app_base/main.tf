module "create_namespace" {
  source                     = "../create_app_namespace"
  environment_name           = var.environment_name
  k8s_namespace              = var.app_name
  k8s_host                   = var.k8s_host
  k8s_cluster_ca_certificate = var.k8s_cluster_ca_certificate
}

module "github_oidc" {
  source = "../register_github_oidc"

  display_name   = "GitHub Actions secret puller - ${var.environment_name} - ${var.app_name}"
  owner          = var.owner
  github_subject = "repo:${var.github_repository_owner}/${var.github_repository}:ref:refs/heads/main"
  key_vault_id   = azurerm_key_vault.app_kv.id
}
