# Mirrors register_github_oidc but without the Key Vault role assignment. The
# resulting SP authenticates to kube-apiserver via kubelogin -l workloadidentity
# in CI; cluster authorization comes from a ClusterRoleBinding bound to its
# object_id, not from Azure RBAC.
resource "azuread_application" "deploy" {
  display_name     = var.display_name
  sign_in_audience = "AzureADMyOrg"
  owners           = [var.owner]
}

resource "azuread_service_principal" "deploy" {
  client_id = azuread_application.deploy.client_id
  owners    = [var.owner]
}

resource "azuread_application_federated_identity_credential" "github_main" {
  application_id = azuread_application.deploy.id
  display_name   = "github-actions-k8s-deploy"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = var.github_subject
}
