terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}

module "postgres_schema" {
  source = "../.."

  resource_group_name = "test"
  azure_location      = "westeurope"
  k8s_oidc_issuer_url = "https://issuer.example.com/"
  schema              = "hello"
  database = {
    host              = "postgres.db"
    port              = 5432
    name              = "postgres"
    jdbc_url          = "jdbc:postgresql://postgres.db:5432/postgres"
    namespace         = "db"
    admin_secret_name = "postgres"
  }
  password_secret = {
    id                      = azurerm_key_vault_secret.password.id
    resource_versionless_id = azurerm_key_vault_secret.password.resource_versionless_id
  }
}

resource "azurerm_key_vault_secret" "password" {
  name         = "db-password"
  key_vault_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.KeyVault/vaults/app"
  value        = module.postgres_schema.password
}
