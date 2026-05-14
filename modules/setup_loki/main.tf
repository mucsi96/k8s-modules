locals {
  loki_release         = "loki"
  alloy_release        = "alloy"
  loki_pv_label        = "loki"
  loki_port            = 3100
  loki_url             = "http://${local.loki_release}.${kubernetes_namespace_v1.logging.metadata[0].name}.svc.cluster.local:${local.loki_port}"
  parseable_release    = "parseable"
  parseable_port       = 8000
  parseable_url        = "http://${local.parseable_release}.${kubernetes_namespace_v1.logging.metadata[0].name}.svc.cluster.local:${local.parseable_port}"
  parseable_secret_name = "parseable-auth"
  parseable_username   = "admin"
  # Parseable creates the stream on first ingest, so this is just the name
  # every Alloy OTLP request advertises via the X-P-Stream header.
  parseable_stream = "k8s"
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
  timeout    = 120

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
  timeout    = 120

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
            forward_to = [
              loki.write.default.receiver,
              otelcol.receiver.loki.parseable.receiver,
            ]

            stage.cri {}
          }

          loki.write "default" {
            endpoint {
              url = "${local.loki_url}/loki/api/v1/push"
            }
          }

          // Bridge the Loki-flow log stream into Alloy's OTLP pipeline so we
          // can dual-write to Parseable, which speaks OTLP HTTP natively but
          // not the Loki push protocol. The receiver converts each Loki
          // entry into an OTLP log record; loki.process's CRI stage has
          // already extracted timestamp and stream metadata by this point.
          otelcol.receiver.loki "parseable" {
            output {
              logs = [otelcol.exporter.otlphttp.parseable.input]
            }
          }

          otelcol.auth.basic "parseable" {
            username = sys.env("P_USERNAME")
            password = sys.env("P_PASSWORD")
          }

          // Parseable accepts OTLP HTTP at /v1/logs (the default path the
          // exporter appends to client.endpoint). The X-P-Stream header
          // tells Parseable which stream to route into; the stream is
          // auto-created on the first request. Credentials come from the
          // parseable-auth Secret mounted as env vars below.
          otelcol.exporter.otlphttp "parseable" {
            client {
              endpoint = "${local.parseable_url}"
              auth     = otelcol.auth.basic.parseable.handler
              headers  = {
                "X-P-Stream" = "${local.parseable_stream}",
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
      # Inject the Parseable admin credentials so the Alloy River config can
      # reference them via sys.env() instead of baking them into the
      # ConfigMap. The Secret is created below and consumed by both Alloy
      # (here, for OTLP basic auth) and the Parseable Helm release (as
      # P_USERNAME / P_PASSWORD env vars on the server pod) so both sides
      # see the same credentials.
      extraEnv = [
        {
          name = "P_USERNAME"
          valueFrom = {
            secretKeyRef = {
              name = local.parseable_secret_name
              key  = "P_USERNAME"
            }
          }
        },
        {
          name = "P_PASSWORD"
          valueFrom = {
            secretKeyRef = {
              name = local.parseable_secret_name
              key  = "P_PASSWORD"
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
    helm_release.parseable,
    kubectl_manifest.parseable_auth,
  ]
}

# Parseable runs as a single-node deployment from the official parseable
# chart, sharing the 'logging' namespace with Loki so the two pipelines can
# be operated and torn down together. Parseable is a logs-only, AGPL
# community-edition log explorer with a modern UI and native JSON field
# extraction; Alloy dual-writes to both backends so Grafana stays usable
# for LogQL while Parseable serves as the primary explorer.

resource "random_password" "parseable_admin" {
  length  = 24
  special = false
}

# Terraform-managed Secret consumed by both Alloy (for OTLP Basic auth) and
# the Parseable Helm release (envFrom on the server pod) so the same
# credentials authenticate ingest and the UI without the chart generating
# its own. sensitive_fields keeps the password out of plan output; the
# values still land in the Secret on the cluster.
resource "kubectl_manifest" "parseable_auth" {
  sensitive_fields = ["stringData.P_PASSWORD"]

  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Secret"
    type       = "Opaque"
    metadata = {
      name      = local.parseable_secret_name
      namespace = kubernetes_namespace_v1.logging.metadata[0].name
    }
    stringData = {
      P_USERNAME = local.parseable_username
      P_PASSWORD = random_password.parseable_admin.result
    }
  })
}

resource "helm_release" "parseable" {
  name       = local.parseable_release
  repository = "https://charts.parseable.com"
  chart      = "parseable"
  version    = var.parseable_chart_version
  namespace  = kubernetes_namespace_v1.logging.metadata[0].name
  wait       = true
  timeout    = 120

  values = [yamlencode(merge(
    {
      # Make every chart-owned resource (StatefulSet, Service, PVC, ...)
      # use the bare release name so the in-cluster service URL stays
      # predictable as 'parseable.logging.svc'.
      fullnameOverride = local.parseable_release
      replicaCount     = 1

      parseable = {
        # local-store keeps WAL, staging and the column store on a single
        # PVC. The s3-store / blob-store modes only pay off once we have
        # an object store and more than one Parseable replica.
        store = "local-store"

        local = {
          enabled      = true
          size         = var.parseable_storage_size
          storageClass = ""
        }

        # Mount P_USERNAME / P_PASSWORD from the Secret above as env vars
        # on the Parseable server pod, instead of letting the chart
        # generate its own admin secret.
        secrets = {
          existingSecret = local.parseable_secret_name
        }
      }

      service = {
        type = "ClusterIP"
        port = local.parseable_port
      }

      ingress = {
        enabled = false
      }
    },
    var.parseable_image_version == "" ? {} : {
      image = {
        tag = var.parseable_image_version
      }
    },
  ))]

  depends_on = [kubectl_manifest.parseable_auth]
}

# Same SSO front-door pattern as Grafana/Prometheus/pgweb: oauth2-proxy
# terminates the Entra OIDC flow and restricts sign-in to var.valid_email.
# Parseable Community Edition has no OIDC support of its own, so passing
# basic_auth_password into the oauth2-proxy module makes it translate the
# authenticated session into 'Authorization: Basic base64(<admin>:<pw>)'
# on every upstream request. Parseable treats those requests as the admin
# user and the UI skips its own login form -- the browser only ever sees
# the Entra sign-in.
module "parseable_oauth2_proxy" {
  source = "../setup_oauth2_proxy"

  name                       = local.parseable_release
  namespace                  = kubernetes_namespace_v1.logging.metadata[0].name
  client_id                  = var.parseable_client_id
  client_secret              = var.parseable_client_secret
  tenant_id                  = var.tenant_id
  valid_email                = var.valid_email
  oauth2_proxy_chart_version = var.oauth2_proxy_chart_version
  oauth2_proxy_image_version = var.oauth2_proxy_image_version
  upstream_uri               = local.parseable_url
  session_redis              = var.session_redis
  basic_auth_password        = random_password.parseable_admin.result

  depends_on = [helm_release.parseable]
}

resource "kubectl_manifest" "parseable_ingressroute" {
  yaml_body = yamlencode({
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = local.parseable_release
      namespace = kubernetes_namespace_v1.logging.metadata[0].name
    }
    spec = {
      entryPoints = ["web"]
      routes = [
        {
          match = "Host(`${var.parseable_hostname}`)"
          kind  = "Rule"
          services = [{
            name = module.parseable_oauth2_proxy.service_name
            port = 80
          }]
        },
      ]
    }
  })

  depends_on = [module.parseable_oauth2_proxy]
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
