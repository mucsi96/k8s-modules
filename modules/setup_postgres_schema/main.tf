resource "random_password" "password" {
  length           = 20
  special          = true
  override_special = "-_=+:[]{}"
}

resource "kubernetes_secret_v1" "credentials" {
  metadata {
    name      = "${replace(var.schema, "_", "-")}-postgres-owner"
    namespace = var.database.namespace
  }

  data = {
    APP_SCHEMA   = var.schema
    APP_USERNAME = var.schema
    APP_PASSWORD = random_password.password.result
  }

  type = "Opaque"
}

resource "kubernetes_config_map_v1" "init" {
  metadata {
    name      = "${replace(var.schema, "_", "-")}-postgres-init"
    namespace = var.database.namespace
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

          env_from {
            secret_ref {
              name = kubernetes_secret_v1.credentials.metadata[0].name
            }
          }

          volume_mount {
            name       = "init-sql"
            mount_path = "/sql"
            read_only  = true
          }

          command = ["/bin/sh", "-euc"]
          args = [
            "until pg_isready; do sleep 2; done; exec psql --single-transaction -v ON_ERROR_STOP=1 -v app_user=\"$APP_USERNAME\" -v app_password=\"$APP_PASSWORD\" -v schema=\"$APP_SCHEMA\" -v database=\"$PGDATABASE\" -f /sql/init.sql"
          ]
        }

        volume {
          name = "init-sql"
          config_map {
            name = kubernetes_config_map_v1.init.metadata[0].name
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
      random_password.password,
      kubernetes_config_map_v1.init,
    ]
  }
}
