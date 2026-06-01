locals {
  release_name = "faro"
  faro_port    = 12347
}

resource "terraform_data" "wait_for" {
  input = var.wait_for
}

# A dedicated Alloy instance running as a faro.receiver. The receiver exposes
# an HTTP endpoint that the Faro Web SDK (running in users' browsers) POSTs
# logs, events, exceptions and measurements to, and forwards them as Loki log
# streams. This is a separate deployment from the Alloy DaemonSet that scrapes
# node pod logs in the logging namespace; the two have different lifecycles
# (one runs per node, one is a single-replica HTTP server) and live in
# different namespaces.
resource "helm_release" "alloy" {
  name       = local.release_name
  repository = "https://grafana.github.io/helm-charts"
  chart      = "alloy"
  version    = var.alloy_chart_version
  namespace  = var.k8s_namespace
  wait       = true
  timeout    = 600

  values = [yamlencode({
    fullnameOverride = local.release_name

    # The 'crds' subchart installs CRDs used by the Alloy operator. We deploy
    # Alloy as a plain Deployment, so the CRDs are unused.
    crds = {
      create = false
    }

    alloy = {
      configMap = {
        create = true
        # faro.receiver attaches a 'kind' label (log/event/exception/measurement)
        # and an 'app' label sourced from the Faro SDK's meta.app.name. The
        # 'app' label matches the pod label promoted by the logging Alloy
        # DaemonSet, so the same Grafana dashboard filter spans backend pod
        # logs and frontend SPA telemetry.
        content = <<-RIVER
          faro.receiver "default" {
            server {
              listen_address           = "0.0.0.0"
              listen_port              = ${local.faro_port}
              cors_allowed_origins     = ${jsonencode(var.cors_allowed_origins)}
              max_allowed_payload_size = "10MiB"
            }

            rate_limiting {
              enabled    = true
              rate       = ${var.rate_limit_rps}
              burst_size = ${var.rate_limit_burst}
            }

            output {
              logs = [loki.write.default.receiver]
            }
          }

          loki.write "default" {
            endpoint {
              url = "${var.loki_url}/loki/api/v1/push"
            }
          }
        RIVER
      }
      # Expose the Faro HTTP port through the Service the chart renders, so
      # the Traefik IngressRoute below can route to it.
      extraPorts = [{
        name       = "faro"
        port       = local.faro_port
        targetPort = local.faro_port
        protocol   = "TCP"
      }]
      # Faro receiver is a single HTTP server — no need for DaemonSet semantics
      # or host mounts. Drop /var/log mounts that the logging DaemonSet needs.
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

  depends_on = [terraform_data.wait_for]
}

# Public route to the Faro receiver. Browsers cannot authenticate against
# oauth2-proxy the way a server-to-server call would, so the endpoint stays
# anonymous and relies on CORS + the receiver's rate limiter to bound abuse.
# Lock down var.cors_allowed_origins to specific SPA origins in production.
resource "kubectl_manifest" "faro_ingressroute" {
  yaml_body = yamlencode({
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "faro"
      namespace = var.k8s_namespace
    }
    spec = {
      entryPoints = ["web"]
      routes = [{
        match = "Host(`${var.hostname}`)"
        kind  = "Rule"
        services = [{
          name = local.release_name
          port = local.faro_port
        }]
      }]
    }
  })

  depends_on = [helm_release.alloy]
}
