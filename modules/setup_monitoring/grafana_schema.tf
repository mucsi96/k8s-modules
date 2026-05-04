resource "kubernetes_secret_v1" "grafana_db" {
  metadata {
    name      = "grafana-db-credentials"
    namespace = kubernetes_namespace_v1.monitoring.metadata[0].name
  }

  data = {
    GF_DATABASE_URL  = local.grafana_db_url
    GF_DATABASE_TYPE = "postgres"
  }

  type = "Opaque"
}

resource "kubernetes_secret_v1" "grafana_schema_psql" {
  metadata {
    name      = "grafana-schema-psql"
    namespace = kubernetes_namespace_v1.monitoring.metadata[0].name
  }

  data = {
    PGHOST     = var.postgres_host
    PGPORT     = tostring(var.postgres_port)
    PGDATABASE = var.postgres_database
    PGUSER     = var.postgres_username
    PGPASSWORD = var.postgres_password
  }

  type = "Opaque"
}

resource "kubernetes_job_v1" "create_grafana_schema" {
  metadata {
    name      = "create-grafana-schema"
    namespace = kubernetes_namespace_v1.monitoring.metadata[0].name
  }

  spec {
    backoff_limit = 6
    template {
      metadata {
        labels = {
          job = "create-grafana-schema"
        }
      }
      spec {
        restart_policy = "OnFailure"

        container {
          name  = "psql"
          image = "postgres:17-alpine"

          env_from {
            secret_ref {
              name = kubernetes_secret_v1.grafana_schema_psql.metadata[0].name
            }
          }

          command = ["/bin/sh", "-c"]
          args = [
            "psql -v ON_ERROR_STOP=1 -c \"CREATE SCHEMA IF NOT EXISTS ${var.grafana_schema} AUTHORIZATION \\\"${var.postgres_username}\\\";\""
          ]
        }
      }
    }
  }

  wait_for_completion = true

  timeouts {
    create = "5m"
    update = "5m"
  }
}
