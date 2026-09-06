resource "random_password" "password" {
  length           = 20
  special          = true
  override_special = "-_=+:[]{}"
}

resource "azurerm_user_assigned_identity" "init" {
  name                = "${var.database.namespace}-${replace(var.schema, "_", "-")}-postgres-init"
  resource_group_name = var.resource_group_name
  location            = var.azure_location
}

resource "kubernetes_service_account_v1" "init" {
  metadata {
    name      = "${replace(var.schema, "_", "-")}-postgres-init"
    namespace = var.database.namespace
    annotations = {
      "azure.workload.identity/client-id" = azurerm_user_assigned_identity.init.client_id
      "azure.workload.identity/tenant-id" = azurerm_user_assigned_identity.init.tenant_id
    }
  }

  automount_service_account_token = false
}

resource "azurerm_federated_identity_credential" "init" {
  name                      = "postgres-init"
  user_assigned_identity_id = azurerm_user_assigned_identity.init.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = var.k8s_oidc_issuer_url
  subject                   = "system:serviceaccount:${var.database.namespace}:${kubernetes_service_account_v1.init.metadata[0].name}"
}

resource "azurerm_role_assignment" "read_password" {
  scope                = var.password_secret.resource_versionless_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.init.principal_id
  principal_type       = "ServicePrincipal"
}

resource "kubernetes_config_map_v1" "init" {
  metadata {
    name      = "${replace(var.schema, "_", "-")}-postgres-init"
    namespace = var.database.namespace
  }

  data = {
    "fetch_password.py" = file("${path.module}/fetch_password.py")
    "init.sql"          = <<-SQL
      \getenv app_password APP_PASSWORD
      SELECT format('CREATE ROLE %I LOGIN', :'app_user')
      WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'app_user')
      \gexec
      SELECT format(
        'DO $check$ BEGIN IF EXISTS (SELECT FROM pg_roles WHERE rolname = %L AND (rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls)) THEN RAISE EXCEPTION ''Refusing to reuse privileged role %%'', %L; END IF; END $check$',
        :'app_user', :'app_user'
      ) \gexec
      SELECT format(
        'ALTER ROLE %I WITH LOGIN PASSWORD %L NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS',
        :'app_user', :'app_password'
      ) \gexec
      SELECT format('GRANT CONNECT, CREATE ON DATABASE %I TO %I', :'database', :'app_user') \gexec
      SELECT format('CREATE SCHEMA IF NOT EXISTS %I AUTHORIZATION %I', :'schema', :'app_user') \gexec
      SELECT format('REVOKE ALL ON SCHEMA %I FROM PUBLIC', :'schema') \gexec
      SELECT format('ALTER ROLE %I IN DATABASE %I SET search_path TO %I, public', :'app_user', :'database', :'schema') \gexec
    SQL
  }
}

# Administrator credentials are referenced directly from the database namespace
# and are never copied into the application namespace or exposed as outputs.
resource "kubernetes_job_v1" "init" {
  metadata {
    name      = "${replace(var.schema, "_", "-")}-postgres-init"
    namespace = var.database.namespace
  }

  spec {
    backoff_limit           = 2
    active_deadline_seconds = 600

    template {
      metadata {
        labels = {
          "azure.workload.identity/use" = "true"
        }
        annotations = {
          "azure.workload.identity/skip-containers" = "psql"
        }
      }

      spec {
        restart_policy                  = "Never"
        service_account_name            = kubernetes_service_account_v1.init.metadata[0].name
        automount_service_account_token = false

        security_context {
          run_as_user     = 999
          run_as_group    = 999
          run_as_non_root = true
          fs_group        = 999
          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        init_container {
          name    = "fetch-password"
          image   = "python:3.13.7-slim-bookworm"
          command = ["python3", "/sql/fetch_password.py"]

          env {
            name  = "PASSWORD_SECRET_URL"
            value = var.password_secret.id
          }

          volume_mount {
            name       = "init-sql"
            mount_path = "/sql"
            read_only  = true
          }

          volume_mount {
            name       = "credentials"
            mount_path = "/credentials"
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            capabilities {
              drop = ["ALL"]
            }
          }

          resources {
            requests = {
              cpu    = "10m"
              memory = "32Mi"
            }
            limits = {
              memory = "64Mi"
            }
          }
        }

        container {
          name  = "psql"
          image = "postgres:18.6"

          env {
            name  = "PGHOST"
            value = var.database.host
          }

          env {
            name  = "PGPORT"
            value = tostring(var.database.port)
          }

          env {
            name  = "PGDATABASE"
            value = var.database.name
          }

          env {
            name = "PGUSER"
            value_from {
              secret_key_ref {
                name = var.database.admin_secret_name
                key  = "username"
              }
            }
          }

          env {
            name = "PGPASSWORD"
            value_from {
              secret_key_ref {
                name = var.database.admin_secret_name
                key  = "password"
              }
            }
          }

          env {
            name  = "APP_SCHEMA"
            value = var.schema
          }

          volume_mount {
            name       = "init-sql"
            mount_path = "/sql"
            read_only  = true
          }

          volume_mount {
            name       = "credentials"
            mount_path = "/credentials"
            read_only  = true
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            capabilities {
              drop = ["ALL"]
            }
          }

          command = ["/bin/sh", "-euc"]
          args = [
            "until pg_isready; do sleep 2; done; APP_PASSWORD=$(cat /credentials/password); export APP_PASSWORD; exec psql -X --single-transaction -v ON_ERROR_STOP=1 -v app_user=\"$APP_SCHEMA\" -v schema=\"$APP_SCHEMA\" -v database=\"$PGDATABASE\" -f /sql/init.sql"
          ]
        }

        volume {
          name = "init-sql"
          config_map {
            name = kubernetes_config_map_v1.init.metadata[0].name
          }
        }

        volume {
          name = "credentials"
          empty_dir {
            medium     = "Memory"
            size_limit = "1Mi"
          }
        }
      }
    }
  }

  timeouts {
    create = "11m"
    update = "11m"
  }

  wait_for_completion = true
  depends_on = [
    azurerm_federated_identity_credential.init,
    azurerm_role_assignment.read_password,
  ]

  lifecycle {
    replace_triggered_by = [
      random_password.password,
      kubernetes_config_map_v1.init,
      kubernetes_service_account_v1.init,
      azurerm_federated_identity_credential.init,
      azurerm_role_assignment.read_password,
    ]
  }
}
