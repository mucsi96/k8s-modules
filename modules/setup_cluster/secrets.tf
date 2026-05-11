# Non-secret kubeconfig that delegates authentication to kubelogin. The exec
# block defaults to `azurecli` (humans run `az login` first); pipelines override
# at runtime by exporting AAD_LOGIN_METHOD=workloadidentity alongside the
# AZURE_* env vars set by azure/login@v3. Stored in Key Vault to mirror the
# k8s-admin-config workflow (scripts/pull_kube_oidc_config.sh fetches it).
resource "azurerm_key_vault_secret" "k8s_oidc_config" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "k8s-oidc-config"
  value = yamlencode({
    apiVersion = "v1"
    kind       = "Config"
    clusters = [{
      name = var.environment_name
      cluster = {
        server                       = data.azurerm_key_vault_secret.k8s_host.value
        "certificate-authority-data" = base64encode(data.azurerm_key_vault_secret.k8s_cluster_ca_certificate.value)
      }
    }]
    contexts = [{
      name = var.environment_name
      context = {
        cluster = var.environment_name
        user    = var.environment_name
      }
    }]
    "current-context" = var.environment_name
    users = [{
      name = var.environment_name
      user = {
        exec = {
          apiVersion = "client.authentication.k8s.io/v1beta1"
          command    = "kubelogin"
          args = [
            "get-token",
            "--login=azurecli",
            "--server-id=${local.apiserver_oidc_client_id}",
            "--tenant-id=${var.azure_tenant_id}",
          ]
        }
      }
    }]
  })
}
