resource "helm_release" "loki" {
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
  version    = var.loki_chart_version
  namespace  = kubernetes_namespace_v1.monitoring.metadata[0].name
  wait       = true
  timeout    = 600

  # https://github.com/grafana/loki/blob/main/production/helm/loki/values.yaml
  values = [yamlencode({
    deploymentMode = "SingleBinary"

    loki = {
      auth_enabled = false

      commonConfig = {
        replication_factor = 1
      }

      schemaConfig = {
        configs = [{
          from         = "2024-01-01"
          store        = "tsdb"
          object_store = "filesystem"
          schema       = "v13"
          index = {
            prefix = "loki_index_"
            period = "24h"
          }
        }]
      }

      storage = {
        type = "filesystem"
      }

      pattern_ingester = {
        enabled = true
      }

      limits_config = {
        allow_structured_metadata = true
        volume_enabled            = true
      }
    }

    singleBinary = {
      replicas = 1

      persistence = {
        enabled = true
        size    = "10Gi"
      }
    }

    # Disable subcomponents that are only relevant in distributed mode.
    backend       = { replicas = 0 }
    read          = { replicas = 0 }
    write         = { replicas = 0 }
    ingester      = { replicas = 0 }
    querier       = { replicas = 0 }
    queryFrontend = { replicas = 0 }
    queryScheduler = { replicas = 0 }
    distributor   = { replicas = 0 }
    compactor     = { replicas = 0 }
    indexGateway  = { replicas = 0 }
    bloomCompactor = { replicas = 0 }
    bloomGateway   = { replicas = 0 }

    # No multi-tenant gateway in single-binary mode.
    gateway = {
      enabled = false
    }

    # Disable the bundled cache; small clusters do not need it.
    chunksCache = {
      enabled = false
    }
    resultsCache = {
      enabled = false
    }

    # Built-in test framework not needed.
    test = {
      enabled = false
    }
    lokiCanary = {
      enabled = false
    }

    # Disable embedded MinIO; using filesystem storage on the singleBinary PVC.
    minio = {
      enabled = false
    }
  })]
}

resource "helm_release" "promtail" {
  name       = "promtail"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "promtail"
  version    = var.promtail_chart_version
  namespace  = kubernetes_namespace_v1.monitoring.metadata[0].name
  wait       = true
  timeout    = 600

  # https://github.com/grafana/helm-charts/blob/main/charts/promtail/values.yaml
  values = [yamlencode({
    config = {
      clients = [
        {
          url = "http://loki.${kubernetes_namespace_v1.monitoring.metadata[0].name}:3100/loki/api/v1/push"
        }
      ]
    }
  })]

  depends_on = [helm_release.loki]
}
