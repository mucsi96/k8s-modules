resource "kubernetes_namespace" "traefik" {
  metadata {
    name = "traefik"
  }
}

resource "helm_release" "traefik" {
  name       = "traefik"
  repository = "https://traefik.github.io/charts"
  chart      = "traefik"
  version    = var.traefik_chart_version
  namespace  = kubernetes_namespace.traefik.metadata[0].name
  wait       = true
  timeout    = 600
  #https://github.com/traefik/traefik-helm-chart/blob/master/traefik/values.yaml
  values = [yamlencode({
    versionOverride = var.traefik_version
    logs = {
      general = {
        level = "DEBUG"
      }
      access = {
        enabled = true
      }
    }
    ingressRoute = {
      dashboard = {
        enabled = true
      }
    }
    service = {
      spec = {
        type = "ClusterIP"
      }
    }
    ports = {
      traefik = {
        expose = {
          default = true
        }
      }
    }
  })]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-lc"]
    command     = <<-EOT
      set -euo pipefail
      export KUBECONFIG="${abspath("${path.module}/../..")}/.kube/admin-config"

      # Wait for the Traefik CRD to be available
      for attempt in $(seq 1 60); do
        if kubectl get crd ingressroutes.traefik.io >/dev/null 2>&1; then
          exit 0
        fi

        echo "Waiting for Traefik CRD ingressroutes.traefik.io (attempt $${attempt}/60)" >&2
        sleep 5
      done

      echo "Timed out waiting for Traefik CRD ingressroutes.traefik.io to become available" >&2
      exit 1
    EOT
  }
}
