locals {
  release_name         = "kube-prometheus-stack"
  grafana_service_name = "${local.release_name}-grafana"
  grafana_port         = 80
  # Service created by the chart for the Prometheus instance managed by the
  # Operator. The default port comes from the Prometheus pod (9090).
  prometheus_service_name = "${local.release_name}-prometheus"
  prometheus_port         = 9090
  email_header_name       = "X-Auth-Request-Email"
}

resource "terraform_data" "wait_for" {
  input = var.wait_for
}

resource "kubernetes_namespace_v1" "monitoring" {
  metadata {
    name = "monitoring"
  }

  depends_on = [terraform_data.wait_for]
}

resource "kubernetes_secret_v1" "grafana_database" {
  metadata {
    name      = "grafana-database"
    namespace = kubernetes_namespace_v1.monitoring.metadata[0].name
  }

  data = {
    username = var.grafana_database.username
    password = var.grafana_database.password
  }

  type = "Opaque"
}

# kube-prometheus-stack bundles the Prometheus Operator together with
# Prometheus, Alertmanager, Grafana, node-exporter and kube-state-metrics. The
# Operator's CRDs (ServiceMonitor, PodMonitor, PrometheusRule, ...) are
# installed by the chart so other modules can ship their own scrape configs and
# alerting rules without managing CRDs separately.
resource "helm_release" "kube_prometheus_stack" {
  name       = local.release_name
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.kube_prometheus_stack_chart_version
  namespace  = kubernetes_namespace_v1.monitoring.metadata[0].name
  wait       = true
  timeout    = 600

  values = [yamlencode({
    crds = {
      enabled = true
    }
    grafana = {
      service = {
        type = "ClusterIP"
        port = local.grafana_port
      }
      ingress = {
        enabled = false
      }
      # Persist Grafana's metadata (dashboards, folders, users, datasources,
      # ...) in PostgreSQL so changes survive pod restarts and chart upgrades.
      # The credentials are mounted from the secret created below to avoid
      # baking them into the rendered Helm values.
      envValueFrom = {
        GF_DATABASE_USER = {
          secretKeyRef = {
            name = kubernetes_secret_v1.grafana_database.metadata[0].name
            key  = "username"
          }
        }
        GF_DATABASE_PASSWORD = {
          secretKeyRef = {
            name = kubernetes_secret_v1.grafana_database.metadata[0].name
            key  = "password"
          }
        }
      }
      # Trust the email header injected by oauth2-proxy. oauth2-proxy already
      # restricts sign-in to var.valid_email, so any request that reaches
      # Grafana with this header is the authorized user. auto_sign_up creates
      # the Grafana account on first login and auto_assign_org_role gives it
      # Admin so dashboards can be edited.
      "grafana.ini" = {
        database = {
          type = "postgres"
          host = "${var.grafana_database.host}:${var.grafana_database.port}"
          name = var.grafana_database.name
          # Postgres deployed by create_postgres_database does not enable TLS;
          # the connection stays inside the cluster network.
          ssl_mode = "disable"
        }
        "auth.proxy" = {
          enabled         = true
          header_name     = local.email_header_name
          header_property = "email"
          auto_sign_up    = true
        }
        auth = {
          disable_login_form   = true
          disable_signout_menu = true
        }
        "auth.basic" = {
          enabled = false
        }
        users = {
          auto_assign_org      = true
          auto_assign_org_role = "Admin"
          allow_sign_up        = false
        }
      }
    }
    prometheus = {
      # The Prometheus UI exposed by the operator-managed StatefulSet has no
      # built-in auth, so we front it with oauth2-proxy below. The Service is
      # ClusterIP-only; external access happens through the IngressRoute.
      service = {
        type = "ClusterIP"
        port = local.prometheus_port
      }
      ingress = {
        enabled = false
      }
      prometheusSpec = {
        # Pick up ServiceMonitor / PodMonitor / PrometheusRule resources from
        # any namespace so apps can ship their own scrape configs.
        serviceMonitorSelectorNilUsesHelmValues = false
        podMonitorSelectorNilUsesHelmValues     = false
        ruleSelectorNilUsesHelmValues           = false
        probeSelectorNilUsesHelmValues          = false
        scrapeConfigSelectorNilUsesHelmValues   = false
      }
    }
    alertmanager = {
      alertmanagerSpec = {
        alertmanagerConfigSelectorNilUsesHelmValues = false
      }
    }
  })]
}

module "grafana_oauth2_proxy" {
  source = "../setup_oauth2_proxy"

  name                       = "grafana"
  namespace                  = kubernetes_namespace_v1.monitoring.metadata[0].name
  client_id                  = var.grafana_client_id
  client_secret              = var.grafana_client_secret
  tenant_id                  = var.tenant_id
  valid_email                = var.valid_email
  oauth2_proxy_chart_version = var.oauth2_proxy_chart_version
  oauth2_proxy_image_version = var.oauth2_proxy_image_version
  upstream_uri               = "http://${local.grafana_service_name}.${kubernetes_namespace_v1.monitoring.metadata[0].name}.svc.cluster.local:${local.grafana_port}"
  session_redis              = var.session_redis

  inject_request_headers = [{
    name = local.email_header_name
    values = [{
      claim = "email"
    }]
  }]

  depends_on = [helm_release.kube_prometheus_stack]
}

module "prometheus_oauth2_proxy" {
  source = "../setup_oauth2_proxy"

  name                       = "prometheus"
  namespace                  = kubernetes_namespace_v1.monitoring.metadata[0].name
  client_id                  = var.prometheus_client_id
  client_secret              = var.prometheus_client_secret
  tenant_id                  = var.tenant_id
  valid_email                = var.valid_email
  oauth2_proxy_chart_version = var.oauth2_proxy_chart_version
  oauth2_proxy_image_version = var.oauth2_proxy_image_version
  upstream_uri               = "http://${local.prometheus_service_name}.${kubernetes_namespace_v1.monitoring.metadata[0].name}.svc.cluster.local:${local.prometheus_port}"
  session_redis              = var.session_redis

  depends_on = [helm_release.kube_prometheus_stack]
}

resource "kubernetes_manifest" "grafana_ingressroute" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "grafana"
      namespace = kubernetes_namespace_v1.monitoring.metadata[0].name
    }
    spec = {
      entryPoints = ["web"]
      routes = [
        {
          match = "Host(`${var.grafana_hostname}`)"
          kind  = "Rule"
          services = [{
            name = module.grafana_oauth2_proxy.service_name
            port = 80
          }]
        },
      ]
    }
  }

  depends_on = [module.grafana_oauth2_proxy]
}

resource "kubernetes_manifest" "prometheus_ingressroute" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "prometheus"
      namespace = kubernetes_namespace_v1.monitoring.metadata[0].name
    }
    spec = {
      entryPoints = ["web"]
      routes = [
        {
          match = "Host(`${var.prometheus_hostname}`)"
          kind  = "Rule"
          services = [{
            name = module.prometheus_oauth2_proxy.service_name
            port = 80
          }]
        },
      ]
    }
  }

  depends_on = [module.prometheus_oauth2_proxy]
}
