locals {
  loki_release       = "loki"
  alloy_release      = "alloy"
  faro_alloy_release = "faro"
  faro_port          = 12347
  loki_pv_label      = "loki"
  loki_port          = 3100
  loki_url           = "http://${local.loki_release}.${kubernetes_namespace_v1.logging.metadata[0].name}.svc.cluster.local:${local.loki_port}"
}

resource "terraform_data" "wait_for" {
  input = var.wait_for
}

resource "kubernetes_namespace_v1" "logging" {
  metadata {
    name = var.k8s_namespace
  }

  depends_on = [terraform_data.wait_for]
}

# Pre-create a hostPath-backed PV so Loki's StatefulSet PVC binds to a known
# location on the node, mirroring how Redis and the central Postgres are
# persisted. The empty storage class disables dynamic provisioning, and the
# label here is matched by persistence.selector below so the StatefulSet's
# volumeClaimTemplate binds to this PV without naming the auto-generated PVC
# explicitly.
resource "kubernetes_persistent_volume_v1" "loki" {
  metadata {
    name = "loki"
    labels = {
      app = local.loki_pv_label
    }
  }

  spec {
    storage_class_name = ""
    access_modes       = ["ReadWriteOnce"]
    capacity = {
      storage = var.loki_storage_size
    }
    persistent_volume_reclaim_policy = "Retain"
    persistent_volume_source {
      host_path {
        path = var.loki_host_path
      }
    }
  }
}

# Loki in single-binary mode: one StatefulSet running ingester, distributor,
# querier and compactor in-process, with the filesystem store backed by the
# hostPath PV above. The read/write/backend microservice modes only pay off
# at higher ingest volumes than this single-node MicroK8s cluster will
# generate, so they're explicitly zeroed out below.
resource "helm_release" "loki" {
  name       = local.loki_release
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
  version    = var.loki_chart_version
  namespace  = kubernetes_namespace_v1.logging.metadata[0].name
  wait       = true
  timeout    = 600

  values = [yamlencode({
    deploymentMode = "SingleBinary"
    loki = {
      auth_enabled = false
      commonConfig = {
        replication_factor = 1
      }
      storage = {
        type = "filesystem"
      }
      schemaConfig = {
        configs = [{
          from         = "2024-04-01"
          store        = "tsdb"
          object_store = "filesystem"
          schema       = "v13"
          index = {
            prefix = "loki_index_"
            period = "24h"
          }
        }]
      }
      pattern_ingester = {
        enabled = true
      }
      limits_config = {
        allow_structured_metadata = true
        volume_enabled            = true
        retention_period          = var.log_retention_period
      }
      compactor = {
        retention_enabled      = true
        retention_delete_delay = "2h"
        delete_request_store   = "filesystem"
      }
    }

    singleBinary = {
      replicas = 1
      persistence = {
        enabled      = true
        storageClass = ""
        size         = var.loki_storage_size
        selector = {
          matchLabels = {
            app = local.loki_pv_label
          }
        }
      }
    }

    # SimpleScalable / microservices roles are unused in single-binary mode.
    read = {
      replicas = 0
    }
    write = {
      replicas = 0
    }
    backend = {
      replicas = 0
    }
    chunksCache = {
      enabled = false
    }
    resultsCache = {
      enabled = false
    }
    gateway = {
      enabled = false
    }
    test = {
      enabled = false
    }
    lokiCanary = {
      enabled = false
    }
    monitoring = {
      # The chart's selfMonitoring mode would install a second Grafana Agent
      # operator just to scrape Loki itself, which duplicates Alloy. The
      # ServiceMonitor below is enough for kube-prometheus-stack to scrape
      # Loki's /metrics endpoint directly.
      selfMonitoring = {
        enabled = false
        grafanaAgent = {
          installOperator = false
        }
      }
      lokiCanary = {
        enabled = false
      }
      serviceMonitor = {
        enabled = true
        metricsInstance = {
          enabled = false
        }
      }
    }
    # Same workaround as setup_prometheus_operator: the kiwigrid/k8s-sidecar
    # the chart runs alongside Loki (loki-sc-rules) calls kube-apiserver over
    # HTTPS using the in-cluster CA. MicroK8s' CA cert is missing the
    # keyUsage extension, which Python 3.14 + OpenSSL 3 rejects ("CA cert
    # does not include key usage extension"), so the sidecar
    # CrashLoopBackOffs and keeps the Loki pod NotReady. The API call stays
    # inside the pod network on every node, so skipping verification only
    # widens the trust boundary to "anything that can already reach the
    # kube-apiserver", which is acceptable here.
    sidecar = {
      skipTlsVerify = true
    }
  })]

  depends_on = [kubernetes_persistent_volume_v1.loki]
}

# Grafana Alloy as a DaemonSet collecting pod logs from /var/log/pods on each
# node and shipping them to Loki. Alloy is the supported successor to the
# deprecated Promtail / Grafana Agent. The River config below discovers pods
# via the Kubernetes API, relabels useful metadata onto each log stream, and
# parses the CRI log line prefix so timestamps and log levels surface
# correctly in Grafana.
resource "helm_release" "alloy" {
  name       = local.alloy_release
  repository = "https://grafana.github.io/helm-charts"
  chart      = "alloy"
  version    = var.alloy_chart_version
  namespace  = kubernetes_namespace_v1.logging.metadata[0].name
  wait       = true
  timeout    = 600

  values = [yamlencode({
    # The 'crds' subchart installs CRDs used by the Alloy operator. We deploy
    # Alloy as a plain DaemonSet, so the CRDs are unused.
    crds = {
      create = false
    }
    alloy = {
      configMap = {
        create  = true
        content = <<-RIVER
          discovery.kubernetes "pods" {
            role = "pod"
          }

          discovery.relabel "pod_logs" {
            targets = discovery.kubernetes.pods.targets

            rule {
              source_labels = ["__meta_kubernetes_namespace"]
              target_label  = "namespace"
            }
            rule {
              source_labels = ["__meta_kubernetes_pod_name"]
              target_label  = "pod"
            }
            rule {
              source_labels = ["__meta_kubernetes_pod_container_name"]
              target_label  = "container"
            }
            rule {
              source_labels = ["__meta_kubernetes_pod_node_name"]
              target_label  = "node"
            }
            rule {
              source_labels = ["__meta_kubernetes_pod_label_app_kubernetes_io_name"]
              target_label  = "app"
            }
            rule {
              action        = "replace"
              source_labels = ["__meta_kubernetes_pod_uid", "__meta_kubernetes_pod_container_name"]
              separator     = "/"
              target_label  = "__path__"
              replacement   = "/var/log/pods/*$1/*.log"
            }
          }

          local.file_match "pods" {
            path_targets = discovery.relabel.pod_logs.output
          }

          loki.source.file "pods" {
            targets    = local.file_match.pods.targets
            forward_to = [loki.process.parse.receiver]
          }

          loki.process "parse" {
            forward_to = [loki.write.default.receiver]

            stage.cri {}
          }

          loki.write "default" {
            endpoint {
              url = "${local.loki_url}/loki/api/v1/push"
            }
          }
        RIVER
      }
      # The chart mounts /var/log from the host into the Alloy container so
      # loki.source.file can read /var/log/pods/*. dockercontainers stays
      # off; MicroK8s uses containerd, not docker, and pod log symlinks under
      # /var/log/pods already point at the right files.
      mounts = {
        varlog           = true
        dockercontainers = false
      }
    }
    controller = {
      type = "daemonset"
    }
  })]

  depends_on = [helm_release.loki]
}

# Grafana Faro: a second Alloy instance running as a faro.receiver. The
# receiver exposes an HTTP endpoint that the Faro Web SDK (running in users'
# browsers) POSTs logs, events, exceptions and measurements to, and forwards
# them as Loki log streams. faro.receiver attaches a 'kind' label
# (log/event/exception/measurement) and an 'app' label sourced from the Faro
# SDK's meta.app.name — the 'app' label matches the pod label promoted by
# the DaemonSet above, so the same Loki query filters span backend pod logs
# and frontend SPA telemetry.
#
# Separate Helm release from the DaemonSet because the two need different
# controller types (DaemonSet for per-node log scraping vs. single-replica
# Deployment for an HTTP receiver).
resource "helm_release" "faro_alloy" {
  name       = local.faro_alloy_release
  repository = "https://grafana.github.io/helm-charts"
  chart      = "alloy"
  version    = var.alloy_chart_version
  namespace  = kubernetes_namespace_v1.logging.metadata[0].name
  wait       = true
  timeout    = 600

  values = [yamlencode({
    fullnameOverride = local.faro_alloy_release

    crds = {
      create = false
    }

    alloy = {
      configMap = {
        create = true
        content = <<-RIVER
          faro.receiver "default" {
            server {
              listen_address           = "0.0.0.0"
              listen_port              = ${local.faro_port}
              cors_allowed_origins     = ${jsonencode(var.faro_cors_allowed_origins)}
              max_allowed_payload_size = "10MiB"
            }

            rate_limiting {
              enabled    = true
              rate       = ${var.faro_rate_limit_rps}
              burst_size = ${var.faro_rate_limit_burst}
            }

            output {
              logs = [loki.write.default.receiver]
            }
          }

          loki.write "default" {
            endpoint {
              url = "${local.loki_url}/loki/api/v1/push"
            }
          }
        RIVER
      }
      # Expose the Faro HTTP port through the Service the chart renders so
      # the Traefik IngressRoute below can route to it.
      extraPorts = [{
        name       = "faro"
        port       = local.faro_port
        targetPort = local.faro_port
        protocol   = "TCP"
      }]
      # Faro receiver is a single HTTP server — no need for DaemonSet
      # semantics or host log mounts.
      mounts = {
        varlog           = false
        dockercontainers = false
      }
    }
    controller = {
      type     = "deployment"
      replicas = 1
    }
  })]

  depends_on = [helm_release.loki]
}

# Public route to the Faro receiver. Browsers cannot authenticate against
# oauth2-proxy the way a server-to-server call would, so the endpoint stays
# anonymous and relies on CORS + the receiver's rate limiter to bound abuse.
# Lock down var.faro_cors_allowed_origins to specific SPA origins in
# production.
resource "kubectl_manifest" "faro_ingressroute" {
  yaml_body = yamlencode({
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "faro"
      namespace = kubernetes_namespace_v1.logging.metadata[0].name
    }
    spec = {
      entryPoints = ["web"]
      routes = [{
        match = "Host(`${var.faro_hostname}`)"
        kind  = "Rule"
        services = [{
          name = local.faro_alloy_release
          port = local.faro_port
        }]
      }]
    }
  })

  depends_on = [helm_release.faro_alloy]
}

# Grafana auto-discovers datasources from any ConfigMap in its namespace
# labeled grafana_datasource=1 (kiwigrid k8s-sidecar). Dropping a single-key
# ConfigMap here is the least intrusive way to wire Loki into the Grafana
# instance owned by setup_prometheus_operator without modifying that module
# or enabling cross-namespace sidecar discovery.
resource "kubernetes_config_map_v1" "loki_datasource" {
  metadata {
    name      = "loki-grafana-datasource"
    namespace = var.grafana_namespace
    labels = {
      grafana_datasource = "1"
    }
  }

  data = {
    "loki-datasource.yaml" = yamlencode({
      apiVersion = 1
      datasources = [{
        name      = "Loki"
        type      = "loki"
        uid       = "loki"
        access    = "proxy"
        url       = local.loki_url
        isDefault = false
        jsonData = {
          maxLines = 1000
        }
      }]
    })
  }

  depends_on = [helm_release.loki]
}
