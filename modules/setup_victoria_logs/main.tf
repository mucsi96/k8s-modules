locals {
  alloy_release      = "alloy"
  faro_alloy_release = "faro"
  faro_port          = 12347
  # Loki-compatible ingestion endpoint of the VLSingle deployed by
  # setup_prometheus_operator. VictoriaLogs speaks the Loki push API under
  # /insert/loki/api/v1/push, so Alloy's loki.write blocks only need this URL.
  victoria_logs_push_url = "${var.victoria_logs_url}/insert/loki/api/v1/push"
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

# Grafana Alloy as a DaemonSet collecting pod logs from /var/log/pods on each
# node and shipping them to VictoriaLogs. Alloy is the supported successor to
# the deprecated Promtail / Grafana Agent. The River config below discovers
# pods via the Kubernetes API, relabels useful metadata onto each log stream,
# and parses the CRI log line prefix so timestamps and log levels surface
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
              url = "${local.victoria_logs_push_url}"
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
}

# Alloy config for the Faro receiver, managed directly as a Kubernetes
# ConfigMap rather than rendered by the chart. The chart pipes
# .Values.alloy.configMap.content through Helm's `tpl` function, which
# re-evaluates any `{{ ... }}` it finds against the chart's context — the
# stage.template Go-template syntax below would otherwise collapse to empty
# strings (we observed `template = " "` in the deployed ConfigMap). Owning
# the ConfigMap from Terraform sidesteps that round-trip entirely.
resource "kubernetes_config_map_v1" "faro_alloy_config" {
  metadata {
    name      = "${local.faro_alloy_release}-config"
    namespace = kubernetes_namespace_v1.logging.metadata[0].name
  }

  data = {
    "config.alloy" = <<-RIVER
      faro.receiver "default" {
        server {
          listen_address           = "0.0.0.0"
          listen_port              = ${local.faro_port}
          cors_allowed_origins     = ${jsonencode(var.faro_cors_allowed_origins)}
          max_allowed_payload_size = "10MiB"

          rate_limiting {
            enabled    = true
            rate       = ${var.faro_rate_limit_rps}
            burst_size = ${var.faro_rate_limit_burst}
          }
        }

        output {
          logs = [loki.process.faro.receiver]
        }
      }

      // The Faro receiver emits each log line as a logfmt blob with every
      // browser/sdk/session field inlined, and only sets service_name as a
      // real stream field (VictoriaLogs groups log entries into streams by
      // their stream fields). The pipeline below:
      //   1. parses the logfmt line into extracted fields;
      //   2. promotes app_name/kind/level to real stream fields so dashboards
      //      can filter with {app="..."} just like for pod logs;
      //   3. moves every other extracted field into the log entry's fields —
      //      still queryable with `| key="value"` and expandable in Grafana,
      //      but out of the log line;
      //   4. rewrites the log line as `<timestamp> [LEVEL] <message>`.
      //      The [LEVEL] bracket is suppressed when level is empty (events,
      //      measurements, exceptions don't have one).
      loki.process "faro" {
        forward_to = [loki.write.default.receiver]

        stage.logfmt {
          mapping = {
            app_name        = "",
            kind            = "",
            level           = "",
            message         = "",
            timestamp       = "",
            event_name      = "",
            event_domain    = "",
            type            = "",
            exception_type  = "",
            exception_value = "",
            sdk_name        = "",
            sdk_version     = "",
            app_version     = "",
            session_id      = "",
            page_url        = "",
            browser_name    = "",
            browser_version = "",
            browser_os      = "",
          }
        }

        stage.labels {
          values = {
            app   = "app_name",
            kind  = "kind",
            level = "level",
          }
        }

        stage.structured_metadata {
          values = {
            event_name      = "event_name",
            event_domain    = "event_domain",
            type            = "type",
            exception_type  = "exception_type",
            exception_value = "exception_value",
            sdk_name        = "sdk_name",
            sdk_version     = "sdk_version",
            app_version     = "app_version",
            session_id      = "session_id",
            page_url        = "page_url",
            browser_name    = "browser_name",
            browser_version = "browser_version",
            browser_os      = "browser_os",
          }
        }

        stage.template {
          source   = "output_line"
          template = "{{ .timestamp | toDate `2006-01-02 15:04:05 -0700 MST` | date `02/Jan/2006:15:04:05` }}{{ if .level }} [{{ .level | upper }}]{{ end }} {{ .message }}"
        }

        stage.output {
          source = "output_line"
        }
      }

      loki.write "default" {
        endpoint {
          url = "${local.victoria_logs_push_url}"
        }
      }
    RIVER
  }
}

# Grafana Faro: a second Alloy instance running as a faro.receiver. The
# receiver exposes an HTTP endpoint that the Faro Web SDK (running in users'
# browsers) POSTs logs, events, exceptions and measurements to, and forwards
# them as log streams to VictoriaLogs. faro.receiver attaches a 'kind' label
# (log/event/exception/measurement) and an 'app' label sourced from the Faro
# SDK's meta.app.name — the 'app' field matches the pod label promoted by
# the DaemonSet above, so the same query filters span backend pod logs
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
      # Reference the externally-managed ConfigMap so the chart's `tpl`
      # round-trip leaves the Go-template syntax in stage.template alone.
      configMap = {
        create = false
        name   = kubernetes_config_map_v1.faro_alloy_config.metadata[0].name
        key    = "config.alloy"
      }
      # Expose the Faro HTTP port through the Service the chart renders so
      # the HTTPRoute below can route to it.
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
      resources = {
        requests = {
          cpu    = "5m"
          memory = "64Mi"
        }
        limits = {
          memory = "128Mi"
        }
      }
    }
    controller = {
      type     = "deployment"
      replicas = 1
    }
  })]

  depends_on = [kubernetes_config_map_v1.faro_alloy_config]
}

# Public route to the Faro receiver. Browsers cannot authenticate against
# oauth2-proxy the way a server-to-server call would, so the endpoint stays
# anonymous and relies on CORS + the receiver's rate limiter to bound abuse.
# Lock down var.faro_cors_allowed_origins to specific SPA origins in
# production.
resource "kubectl_manifest" "faro_httproute" {
  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "faro"
      namespace = kubernetes_namespace_v1.logging.metadata[0].name
    }
    spec = {
      parentRefs = [{
        name        = "traefik"
        namespace   = "traefik"
        sectionName = "websecure"
      }]
      hostnames = [var.faro_hostname]
      rules = [{
        backendRefs = [{
          name = local.faro_alloy_release
          port = local.faro_port
        }]
      }]
    }
  })

  depends_on = [helm_release.faro_alloy]
}

