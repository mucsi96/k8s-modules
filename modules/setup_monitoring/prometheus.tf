resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.kube_prometheus_stack_chart_version
  namespace  = kubernetes_namespace_v1.monitoring.metadata[0].name
  wait       = true
  timeout    = 900

  # https://github.com/prometheus-community/helm-charts/blob/main/charts/kube-prometheus-stack/values.yaml
  values = [yamlencode({
    prometheus = {
      prometheusSpec = {
        podMonitorSelectorNilUsesHelmValues     = false
        serviceMonitorSelectorNilUsesHelmValues = false
        ruleSelectorNilUsesHelmValues           = false
        probeSelectorNilUsesHelmValues          = false
      }
    }

    grafana = {
      # Disable the default ingress; Traefik IngressRoute is provisioned separately.
      ingress = {
        enabled = false
      }

      # Persist Grafana metadata (dashboards, users, datasources, ...) in Postgres.
      # Wiring through env so the password is not rendered into a ConfigMap.
      envFromSecret = kubernetes_secret_v1.grafana_db.metadata[0].name

      # Disable persistent volume claim because all stateful data is in Postgres now.
      persistence = {
        enabled = false
      }

      # Trust the Traefik forward-auth header populated upstream by Cloudflare Access.
      "grafana.ini" = {
        "auth.proxy" = {
          enabled        = true
          header_name    = "X-WEBAUTH-USER"
          header_property = "username"
          auto_sign_up   = true
        }
        server = {
          root_url           = "https://${local.grafana_host}/"
          serve_from_sub_path = false
        }
      }

      additionalDataSources = [
        {
          name      = "Loki"
          type      = "loki"
          isDefault = false
          access    = "proxy"
          url       = "http://loki.${kubernetes_namespace_v1.monitoring.metadata[0].name}:3100"
          version   = 1
        },
        {
          name      = "Postgres"
          type      = "postgres"
          access    = "proxy"
          url       = "${var.postgres_host}:${var.postgres_port}"
          user      = var.postgres_username
          database  = var.postgres_database
          isDefault = false
          jsonData = {
            sslmode         = "disable"
            postgresVersion = 1600
            timescaledb     = false
          }
          secureJsonData = {
            password = var.postgres_password
          }
        }
      ]

      sidecar = {
        dashboards = {
          enabled         = true
          searchNamespace = "ALL"
          label           = "grafana_dashboard"
          provider = {
            # Allow UI edits of provisioned dashboards. Edits persist to the
            # Postgres-backed Grafana database, not the read-only ConfigMap.
            allowUiUpdates = true
          }
        }
      }
    }
  })]

  depends_on = [
    kubernetes_job_v1.create_grafana_schema,
  ]
}
