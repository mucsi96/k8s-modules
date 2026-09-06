mock_provider "azurerm" {
  mock_resource "azurerm_user_assigned_identity" {
    defaults = {
      id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/postgres-init"
      client_id    = "00000000-0000-0000-0000-000000000001"
      principal_id = "00000000-0000-0000-0000-000000000002"
      tenant_id    = "00000000-0000-0000-0000-000000000003"
    }
  }
  mock_resource "azurerm_key_vault_secret" {
    defaults = {
      id                      = "https://app.vault.azure.net/secrets/db-password/version"
      resource_versionless_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.KeyVault/vaults/app/secrets/db-password"
    }
  }
}
mock_provider "kubernetes" {}
mock_provider "random" {
  mock_resource "random_password" {
    defaults = {
      result = "test-only-password-123"
    }
  }
}

variables {
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
    id                      = "https://app.vault.azure.net/secrets/db-password/version"
    resource_versionless_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/test/providers/Microsoft.KeyVault/vaults/app/secrets/db-password"
  }
}

run "vault_backed_job" {
  command = apply

  assert {
    condition     = azurerm_role_assignment.read_password.scope == var.password_secret.resource_versionless_id
    error_message = "The provisioning identity must read only its password secret."
  }

  assert {
    condition     = kubernetes_job_v1.init.spec[0].template[0].spec[0].init_container[0].env[0].value == var.password_secret.id
    error_message = "The fetcher must read the exact managed password version."
  }

  assert {
    condition     = azurerm_federated_identity_credential.init.subject == "system:serviceaccount:db:hello-postgres-init"
    error_message = "Federation must be scoped to this Job's ServiceAccount."
  }

  assert {
    condition = (
      kubernetes_job_v1.init.spec[0].template[0].metadata[0].labels["azure.workload.identity/use"] == "true" &&
      kubernetes_job_v1.init.spec[0].template[0].metadata[0].annotations["azure.workload.identity/skip-containers"] == "psql" &&
      kubernetes_job_v1.init.spec[0].template[0].spec[0].service_account_name == kubernetes_service_account_v1.init.metadata[0].name &&
      !kubernetes_job_v1.init.spec[0].template[0].spec[0].automount_service_account_token
    )
    error_message = "Only the fetcher should receive a projected workload identity token."
  }

  assert {
    condition = anytrue([
      for volume in kubernetes_job_v1.init.spec[0].template[0].spec[0].volume :
      volume.name == "credentials" && try(volume.empty_dir[0].medium == "Memory", false)
    ])
    error_message = "The fetched password must be held on a memory-backed volume."
  }

  assert {
    condition = !strcontains(jsonencode([
      kubernetes_job_v1.init.spec,
      kubernetes_config_map_v1.init.data,
    ]), random_password.password.result)
    error_message = "Do not render the app password into Kubernetes objects."
  }

  assert {
    condition     = output.credentials.password == output.password && output.credentials.username == var.schema
    error_message = "Keep the generated password and existing credential output unchanged."
  }
}

run "vault_publication_backedge" {
  command = apply
  providers = {
    azurerm    = azurerm
    kubernetes = kubernetes
    random     = random
  }
  module {
    source = "./tests/vault_wiring"
  }
}
