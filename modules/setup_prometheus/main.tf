locals {
  release_name              = "kube-prometheus-stack"
  prometheus_service_name   = "${local.release_name}-prometheus"
  alertmanager_service_name = "${local.release_name}-alertmanager"
  grafana_service_name      = "${local.release_name}-grafana"
  prometheus_service_port   = 9090
  grafana_service_port      = 80
}

resource "terraform_data" "wait_for" {
  input = var.wait_for
}

resource "kubernetes_namespace_v1" "prometheus" {
  metadata {
    name = "prometheus"
  }

  depends_on = [terraform_data.wait_for]
}

resource "helm_release" "kube_prometheus_stack" {
  name       = local.release_name
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.kube_prometheus_stack_chart_version
  namespace  = kubernetes_namespace_v1.prometheus.metadata[0].name
  wait       = true
  timeout    = 900

  values = [yamlencode({
    prometheus = {
      prometheusSpec = {
        image = {
          tag = var.prometheus_image_version
        }
        serviceMonitorSelectorNilUsesHelmValues = false
        podMonitorSelectorNilUsesHelmValues     = false
        ruleSelectorNilUsesHelmValues           = false
        probeSelectorNilUsesHelmValues          = false
      }
      service = {
        type = "ClusterIP"
        port = local.prometheus_service_port
      }
    }
    alertmanager = {
      alertmanagerSpec = {
        image = {
          tag = var.alertmanager_image_version
        }
      }
    }
    grafana = {
      image = {
        tag = var.grafana_image_version
      }
      service = {
        type = "ClusterIP"
        port = local.grafana_service_port
      }
      persistence = {
        enabled = false
      }
      "grafana.ini" = {
        server = {
          root_url = "https://${var.grafana_hostname}/"
        }
        database = {
          type     = "postgres"
          host     = "${var.grafana_database.host}:${var.grafana_database.port}"
          name     = var.grafana_database.name
          user     = var.grafana_database.user
          password = var.grafana_database.password
          ssl_mode = "disable"
        }
        auth = {
          disable_login_form = true
        }
        "auth.basic" = {
          enabled = false
        }
        "auth.anonymous" = {
          enabled = false
        }
        # oauth2-proxy authenticates the user and forwards the email in
        # X-WEBAUTH-USER; Grafana auto-provisions a matching user on first hit.
        "auth.proxy" = {
          enabled         = true
          header_name     = "X-WEBAUTH-USER"
          header_property = "username"
          auto_sign_up    = true
          sync_ttl        = 60
          headers         = "Email:X-WEBAUTH-EMAIL"
        }
        users = {
          auto_assign_org      = true
          auto_assign_org_role = "Editor"
          allow_sign_up        = false
        }
      }
    }
  })]
}
