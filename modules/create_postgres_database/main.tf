resource "random_string" "db_username" {
  length  = 12
  upper   = false
  numeric = false
  special = false
}

resource "random_password" "admin_password_blue" {
  length           = 20
  special          = true
  override_special = "-_=+:[]{}" // verified: []
  keepers = var.admin_password_blue_generation == null ? null : {
    generation = var.admin_password_blue_generation
  }
}

moved {
  from = random_password.db_password
  to   = random_password.admin_password_blue
}

resource "random_password" "admin_password_green" {
  length           = 20
  special          = true
  override_special = "-_=+:[]{}" // verified: []
  keepers = {
    generation = var.admin_password_green_generation
  }
}

resource "random_password" "schema_owner" {
  for_each = var.application_schemas

  length           = 20
  special          = true
  override_special = "-_=+:[]{}"
}

resource "random_string" "exporter_username" {
  length  = 12
  upper   = false
  numeric = false
  special = false
}

resource "random_password" "exporter_password" {
  length           = 20
  special          = true
  override_special = "-_=+:[]{}" // verified: []
}

resource "terraform_data" "wait_for" {
  input = var.wait_for
}

resource "terraform_data" "role_provisioning_generation" {
  input = var.role_provisioning_generation
}

locals {
  admin_target_password   = var.admin_password_active_slot == "blue" ? random_password.admin_password_blue.result : random_password.admin_password_green.result
  admin_previous_password = var.admin_password_active_slot == "blue" ? random_password.admin_password_green.result : random_password.admin_password_blue.result
}

resource "kubernetes_persistent_volume_v1" "database_pv" {
  metadata {
    name = "database"
  }

  spec {
    storage_class_name = ""
    access_modes       = ["ReadWriteOnce"]
    capacity = {
      storage = "5Gi"
    }
    persistent_volume_reclaim_policy = "Retain"
    persistent_volume_source {
      host_path {
        path = "/data/database"
      }
    }
  }
}

resource "helm_release" "database" {
  name       = var.k8s_name
  repository = "https://mucsi96.github.io/k8s-helm-charts"
  chart      = "postgres-db"
  version    = "16.0.0"
  namespace  = var.k8s_namespace
  wait       = true
  # https://github.com/mucsi96/k8s-helm-charts/tree/main/charts/postgres_db
  values = [yamlencode({
    name = var.db_name
    persistentVolumeClaim = {
      storageClassName = ""
      volumeName       = kubernetes_persistent_volume_v1.database_pv.metadata[0].name
      accessMode       = "ReadWriteOnce"
    }
    username         = random_string.db_username.result
    password         = local.admin_target_password
    exporterUsername = random_string.exporter_username.result
    exporterPassword = random_password.exporter_password.result
  })]

  # The chart ships a ServiceMonitor (monitoring.coreos.com/v1); the Prometheus
  # Operator CRDs must already exist or the release fails at manifest build.
  depends_on = [terraform_data.wait_for]
}

resource "kubernetes_secret_v1" "schema_owner" {
  for_each = var.application_schemas

  metadata {
    name      = "postgres-role-${substr(sha256(each.key), 0, 12)}"
    namespace = var.k8s_namespace
  }

  data = {
    APP_SCHEMA   = each.key
    APP_USERNAME = each.key
    APP_PASSWORD = random_password.schema_owner[each.key].result
  }

  type = "Opaque"
}

resource "kubernetes_secret_v1" "admin_rotation" {
  metadata {
    name      = "${var.k8s_name}-admin-rotation"
    namespace = var.k8s_namespace
  }

  data = {
    ADMIN_USERNAME          = random_string.db_username.result
    ADMIN_PREVIOUS_PASSWORD = local.admin_previous_password
    ADMIN_TARGET_PASSWORD   = local.admin_target_password
  }

  type = "Opaque"
}

resource "kubernetes_config_map_v1" "schema_owner_init" {
  metadata {
    name      = "${var.k8s_name}-schema-owner-init"
    namespace = var.k8s_namespace
  }

  data = {
    "init.sql" = <<-SQL
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

      SELECT format(
        CASE c.relkind
          WHEN 'S' THEN 'ALTER SEQUENCE %s OWNER TO %I'
          WHEN 'v' THEN 'ALTER VIEW %s OWNER TO %I'
          WHEN 'm' THEN 'ALTER MATERIALIZED VIEW %s OWNER TO %I'
          WHEN 'f' THEN 'ALTER FOREIGN TABLE %s OWNER TO %I'
          ELSE 'ALTER TABLE %s OWNER TO %I'
        END,
        format('%I.%I', n.nspname, c.relname),
        :'app_user'
      )
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = :'schema'
        AND c.relkind IN ('r', 'p', 'S', 'v', 'm', 'f')
      ORDER BY CASE WHEN c.relkind = 'S' THEN 1 ELSE 0 END
      \gexec

      SELECT format(
        CASE p.prokind
          WHEN 'p' THEN 'ALTER PROCEDURE %s OWNER TO %I'
          WHEN 'a' THEN 'ALTER AGGREGATE %s OWNER TO %I'
          ELSE 'ALTER FUNCTION %s OWNER TO %I'
        END,
        format('%I.%I(%s)', n.nspname, p.proname, pg_get_function_identity_arguments(p.oid)),
        :'app_user'
      )
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = :'schema'
      \gexec

      SELECT format('ALTER TYPE %I.%I OWNER TO %I', n.nspname, t.typname, :'app_user')
      FROM pg_type t
      JOIN pg_namespace n ON n.oid = t.typnamespace
      LEFT JOIN pg_class c ON c.oid = t.typrelid
      WHERE n.nspname = :'schema'
        AND (t.typtype IN ('d', 'e', 'r', 'm') OR (t.typtype = 'c' AND c.relkind = 'c'))
      \gexec

      SELECT format('ALTER SCHEMA %I OWNER TO %I', :'schema', :'app_user') \gexec
      SELECT format('ALTER ROLE %I IN DATABASE %I SET search_path TO %I, public', :'app_user', :'database', :'schema') \gexec
    SQL

    "rotate-admin.sql" = <<-SQL
      SELECT format('ALTER ROLE %I WITH PASSWORD %L', :'admin_user', :'admin_password') \gexec
    SQL
  }
}

# Bootstrap credentials remain confined to the database namespace and these
# short-lived provisioning Jobs. Runtime consumers receive only the credentials
# for the schema they own.
resource "kubernetes_job_v1" "schema_owner_init" {
  for_each = var.application_schemas

  metadata {
    name      = "postgres-role-${substr(sha256(each.key), 0, 12)}-init"
    namespace = var.k8s_namespace
  }

  spec {
    backoff_limit = 5

    template {
      metadata {}

      spec {
        restart_policy = "OnFailure"

        container {
          name  = "psql"
          image = "postgres:18.6"

          env {
            name  = "PGHOST"
            value = "${var.k8s_name}.${var.k8s_namespace}"
          }

          env {
            name  = "PGPORT"
            value = "5432"
          }

          env {
            name  = "PGDATABASE"
            value = var.db_name
          }

          env {
            name  = "PGUSER"
            value = random_string.db_username.result
          }

          env_from {
            secret_ref {
              name = kubernetes_secret_v1.admin_rotation.metadata[0].name
            }
          }

          env_from {
            secret_ref {
              name = kubernetes_secret_v1.schema_owner[each.key].metadata[0].name
            }
          }

          volume_mount {
            name       = "init-sql"
            mount_path = "/sql"
            read_only  = true
          }

          command = ["/bin/sh", "-euc"]
          args = [
            "until pg_isready; do sleep 2; done; if PGPASSWORD=\"$ADMIN_TARGET_PASSWORD\" psql -c 'SELECT 1' >/dev/null 2>&1; then export PGPASSWORD=\"$ADMIN_TARGET_PASSWORD\"; else export PGPASSWORD=\"$ADMIN_PREVIOUS_PASSWORD\"; fi; exec psql --single-transaction -v ON_ERROR_STOP=1 -v app_user=\"$APP_USERNAME\" -v app_password=\"$APP_PASSWORD\" -v schema=\"$APP_SCHEMA\" -v database=\"$PGDATABASE\" -f /sql/init.sql"
          ]
        }

        volume {
          name = "init-sql"
          config_map {
            name = kubernetes_config_map_v1.schema_owner_init.metadata[0].name
          }
        }
      }
    }
  }

  timeouts {
    create = "5m"
    update = "5m"
  }

  lifecycle {
    replace_triggered_by = [
      random_password.schema_owner[each.key],
      kubernetes_config_map_v1.schema_owner_init,
      helm_release.database,
      terraform_data.role_provisioning_generation,
    ]
  }

  depends_on = [helm_release.database]
}

# Existing installations previously distributed the bootstrap password to all
# applications. Rotate it only after every schema has a dedicated owner so old
# Key Vault versions and historical logs can no longer authenticate.
resource "kubernetes_job_v1" "admin_rotation" {
  metadata {
    name      = "${var.k8s_name}-admin-rotation"
    namespace = var.k8s_namespace
  }

  spec {
    backoff_limit = 5

    template {
      metadata {}

      spec {
        restart_policy = "OnFailure"

        container {
          name  = "psql"
          image = "postgres:18.6"

          env {
            name  = "PGHOST"
            value = "${var.k8s_name}.${var.k8s_namespace}"
          }

          env {
            name  = "PGPORT"
            value = "5432"
          }

          env {
            name  = "PGDATABASE"
            value = var.db_name
          }

          env {
            name  = "PGUSER"
            value = random_string.db_username.result
          }

          env_from {
            secret_ref {
              name = kubernetes_secret_v1.admin_rotation.metadata[0].name
            }
          }

          volume_mount {
            name       = "init-sql"
            mount_path = "/sql"
            read_only  = true
          }

          command = ["/bin/sh", "-euc"]
          args = [
            "until pg_isready; do sleep 2; done; if PGPASSWORD=\"$ADMIN_TARGET_PASSWORD\" psql -c 'SELECT 1' >/dev/null 2>&1; then export PGPASSWORD=\"$ADMIN_TARGET_PASSWORD\"; else export PGPASSWORD=\"$ADMIN_PREVIOUS_PASSWORD\"; fi; exec psql --single-transaction -v ON_ERROR_STOP=1 -v admin_user=\"$ADMIN_USERNAME\" -v admin_password=\"$ADMIN_TARGET_PASSWORD\" -f /sql/rotate-admin.sql"
          ]
        }

        volume {
          name = "init-sql"
          config_map {
            name = kubernetes_config_map_v1.schema_owner_init.metadata[0].name
          }
        }
      }
    }
  }

  timeouts {
    create = "5m"
    update = "5m"
  }

  lifecycle {
    replace_triggered_by = [
      random_password.admin_password_blue,
      random_password.admin_password_green,
      kubernetes_config_map_v1.schema_owner_init,
      helm_release.database,
      terraform_data.role_provisioning_generation,
    ]
  }

  depends_on = [kubernetes_job_v1.schema_owner_init]
}
