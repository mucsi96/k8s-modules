locals {
  loki_release         = "loki"
  alloy_release        = "alloy"
  loki_pv_label        = "loki"
  loki_port            = 3100
  loki_url             = "http://${local.loki_release}.${kubernetes_namespace_v1.logging.metadata[0].name}.svc.cluster.local:${local.loki_port}"
  openobserve_name     = "openobserve"
  openobserve_pv_label = "openobserve"
  openobserve_http     = 5080
  openobserve_grpc     = 5081
  openobserve_org      = "default"
  openobserve_url      = "http://${local.openobserve_name}.${kubernetes_namespace_v1.logging.metadata[0].name}.svc.cluster.local:${local.openobserve_http}"
  openobserve_loki_push_path = "/api/${local.openobserve_org}/loki/api/v1/push"
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
            forward_to = [loki.write.default.receiver, loki.write.openobserve.receiver]

            stage.cri {}
          }

          loki.write "default" {
            endpoint {
              url = "${local.loki_url}/loki/api/v1/push"
            }
          }

          // Dual-write the same parsed log stream to OpenObserve via its Loki
          // ingest compatibility endpoint. OpenObserve auto-extracts JSON
          // fields from the log line on ingest, giving a Splunk-style search
          // experience without changing the collector. Basic auth credentials
          // come from the openobserve-root Secret mounted as env vars below.
          loki.write "openobserve" {
            endpoint {
              url = "${local.openobserve_url}${local.openobserve_loki_push_path}"
              basic_auth {
                username = sys.env("ZO_ROOT_USER_EMAIL")
                password = sys.env("ZO_ROOT_USER_PASSWORD")
              }
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
      # Inject the OpenObserve root credentials so the Alloy River config can
      # reference them via sys.env() instead of baking them into the
      # ConfigMap. The Secret is created below and shared with the
      # OpenObserve StatefulSet so both sides see the same credentials.
      extraEnv = [
        {
          name = "ZO_ROOT_USER_EMAIL"
          valueFrom = {
            secretKeyRef = {
              name = kubernetes_secret_v1.openobserve_root.metadata[0].name
              key  = "ZO_ROOT_USER_EMAIL"
            }
          }
        },
        {
          name = "ZO_ROOT_USER_PASSWORD"
          valueFrom = {
            secretKeyRef = {
              name = kubernetes_secret_v1.openobserve_root.metadata[0].name
              key  = "ZO_ROOT_USER_PASSWORD"
            }
          }
        },
      ]
    }
    controller = {
      type = "daemonset"
    }
  })]

  depends_on = [
    helm_release.loki,
    kubernetes_stateful_set_v1.openobserve,
  ]
}

# OpenObserve runs as a single-node StatefulSet alongside Loki, sharing the
# 'logging' namespace so the two pipelines can be operated and torn down
# together. OpenObserve provides a Splunk-style log viewer with first-class
# JSON field extraction; Alloy dual-writes to both backends so Grafana stays
# usable for LogQL while OpenObserve serves as the primary explorer.

resource "random_password" "openobserve_root" {
  length  = 24
  special = false
}

resource "kubernetes_secret_v1" "openobserve_root" {
  metadata {
    name      = "openobserve-root"
    namespace = kubernetes_namespace_v1.logging.metadata[0].name
  }

  data = {
    ZO_ROOT_USER_EMAIL    = var.valid_email
    ZO_ROOT_USER_PASSWORD = random_password.openobserve_root.result
  }

  type = "Opaque"
}

# Pre-created hostPath PV bound to the StatefulSet's volumeClaimTemplate via
# the selector below. Mirrors the Loki PV pattern so OpenObserve's data
# directory survives pod restarts and lives at a known location on the node.
resource "kubernetes_persistent_volume_v1" "openobserve" {
  metadata {
    name = "openobserve"
    labels = {
      app = local.openobserve_pv_label
    }
  }

  spec {
    storage_class_name = ""
    access_modes       = ["ReadWriteOnce"]
    capacity = {
      storage = var.openobserve_storage_size
    }
    persistent_volume_reclaim_policy = "Retain"
    persistent_volume_source {
      host_path {
        path = var.openobserve_host_path
      }
    }
  }
}

resource "kubernetes_service_v1" "openobserve" {
  metadata {
    name      = local.openobserve_name
    namespace = kubernetes_namespace_v1.logging.metadata[0].name
    labels = {
      app = local.openobserve_name
    }
  }

  spec {
    type = "ClusterIP"
    selector = {
      app = local.openobserve_name
    }
    port {
      name        = "http"
      port        = local.openobserve_http
      target_port = local.openobserve_http
      protocol    = "TCP"
    }
    port {
      name        = "grpc"
      port        = local.openobserve_grpc
      target_port = local.openobserve_grpc
      protocol    = "TCP"
    }
  }
}

resource "kubernetes_stateful_set_v1" "openobserve" {
  metadata {
    name      = local.openobserve_name
    namespace = kubernetes_namespace_v1.logging.metadata[0].name
    labels = {
      app = local.openobserve_name
    }
  }

  spec {
    service_name = kubernetes_service_v1.openobserve.metadata[0].name
    replicas     = 1

    selector {
      match_labels = {
        app = local.openobserve_name
      }
    }

    template {
      metadata {
        labels = {
          app = local.openobserve_name
        }
      }

      spec {
        # OpenObserve writes its WAL, indices and files store under
        # ZO_DATA_DIR. The container runs as a non-root user, so the
        # hostPath-backed PV needs to be writable; an fsGroup ensures the
        # mounted volume is chowned to the container's group on attach.
        security_context {
          fs_group = 2000
        }

        container {
          name  = local.openobserve_name
          image = "public.ecr.aws/zinclabs/openobserve:${var.openobserve_image_version}"

          env_from {
            secret_ref {
              name = kubernetes_secret_v1.openobserve_root.metadata[0].name
            }
          }

          env {
            name  = "ZO_DATA_DIR"
            value = "/data"
          }

          env {
            name  = "ZO_LOCAL_MODE"
            value = "true"
          }

          env {
            name  = "ZO_HTTP_PORT"
            value = tostring(local.openobserve_http)
          }

          env {
            name  = "ZO_GRPC_PORT"
            value = tostring(local.openobserve_grpc)
          }

          port {
            name           = "http"
            container_port = local.openobserve_http
          }
          port {
            name           = "grpc"
            container_port = local.openobserve_grpc
          }

          volume_mount {
            name       = "data"
            mount_path = "/data"
          }

          readiness_probe {
            http_get {
              path = "/healthz"
              port = local.openobserve_http
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }

          liveness_probe {
            http_get {
              path = "/healthz"
              port = local.openobserve_http
            }
            initial_delay_seconds = 30
            period_seconds        = 30
          }
        }
      }
    }

    volume_claim_template {
      metadata {
        name = "data"
      }
      spec {
        access_modes       = ["ReadWriteOnce"]
        storage_class_name = ""
        resources {
          requests = {
            storage = var.openobserve_storage_size
          }
        }
        selector {
          match_labels = {
            app = local.openobserve_pv_label
          }
        }
      }
    }
  }

  depends_on = [kubernetes_persistent_volume_v1.openobserve]
}

# Same SSO front-door pattern as Grafana/Prometheus/pgweb: oauth2-proxy
# terminates the Entra OIDC flow, restricts sign-in to var.valid_email and
# proxies authenticated requests to OpenObserve's ClusterIP service. The
# OpenObserve UI itself still asks for credentials once on first visit
# (browser cookie persists after); those bootstrap credentials are the same
# ones Alloy uses to ingest, stored in the openobserve-root Secret.
module "openobserve_oauth2_proxy" {
  source = "../setup_oauth2_proxy"

  name                       = local.openobserve_name
  namespace                  = kubernetes_namespace_v1.logging.metadata[0].name
  client_id                  = var.openobserve_client_id
  client_secret              = var.openobserve_client_secret
  tenant_id                  = var.tenant_id
  valid_email                = var.valid_email
  oauth2_proxy_chart_version = var.oauth2_proxy_chart_version
  oauth2_proxy_image_version = var.oauth2_proxy_image_version
  upstream_uri               = "http://${kubernetes_service_v1.openobserve.metadata[0].name}.${kubernetes_namespace_v1.logging.metadata[0].name}.svc.cluster.local:${local.openobserve_http}"
  session_redis              = var.session_redis

  depends_on = [kubernetes_stateful_set_v1.openobserve]
}

resource "kubectl_manifest" "openobserve_ingressroute" {
  yaml_body = yamlencode({
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = local.openobserve_name
      namespace = kubernetes_namespace_v1.logging.metadata[0].name
    }
    spec = {
      entryPoints = ["web"]
      routes = [
        {
          match = "Host(`${var.openobserve_hostname}`)"
          kind  = "Rule"
          services = [{
            name = module.openobserve_oauth2_proxy.service_name
            port = 80
          }]
        },
      ]
    }
  })

  depends_on = [module.openobserve_oauth2_proxy]
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
