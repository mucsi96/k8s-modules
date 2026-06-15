locals {
  release_name         = "kube-prometheus-stack"
  grafana_service_name = "${local.release_name}-grafana"
  grafana_port         = 80
  # Service created by the chart for the Prometheus instance managed by the
  # Operator. The default port comes from the Prometheus pod (9090).
  prometheus_service_name = "${local.release_name}-prometheus"
  prometheus_port         = 9090
  email_header_name       = "X-Auth-Request-Email"
  grafana_db_user         = "grafana"
  grafana_db_schema       = "grafana"

  # Grafana's server-admin account. Pinned here rather than left to the grafana
  # subchart's random adminPassword (regenerated on every from-scratch install)
  # so the credentials stay identical across cluster reprovisions and targeted
  # destroys. A database backup restored into a fresh cluster then keeps
  # matching the running config, and the kiwigrid sidecars keep authenticating
  # after a restore instead of 401-ing once the random password rotates.
  #
  # Real user authentication is OIDC through oauth2-proxy and the login form is
  # disabled, so the human admin signs in via the email header (mapped to this
  # same account because the login equals their email). This password therefore
  # only backs the in-cluster sidecar Basic Auth calls and emergency access;
  # external traffic is gated by the HTTPRoute -> oauth2-proxy in front of
  # Grafana, so a static value here does not widen the external attack surface.
  grafana_admin_user     = var.valid_email
  grafana_admin_password = "Grafana-Admin-Stable-2026"

  # Static key for Grafana's envelope encryption and signed settings. Pinned so
  # secrets stored in the database (datasource credentials, the data_keys table)
  # stay decryptable across reprovisions and restores. The subchart otherwise
  # leaves this at Grafana's well-known built-in default value.
  grafana_secret_key = "k8sGrafanaEnvelopeKeyStable2026xQ"
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

resource "random_password" "grafana_db_password" {
  length           = 20
  special          = true
  override_special = "-_=+:[]{}"
}

resource "kubernetes_secret_v1" "grafana_database" {
  metadata {
    name      = "grafana-database"
    namespace = kubernetes_namespace_v1.monitoring.metadata[0].name
  }

  data = {
    PG_HOST           = var.database.host
    PG_PORT           = tostring(var.database.port)
    PG_DATABASE       = var.database.name
    PG_ADMIN_USER     = var.database.admin_username
    PG_ADMIN_PASSWORD = var.database.admin_password
    PG_SCHEMA         = local.grafana_db_schema
    GRAFANA_USER      = local.grafana_db_user
    GRAFANA_PASSWORD  = random_password.grafana_db_password.result
  }

  type = "Opaque"
}

resource "kubernetes_config_map_v1" "grafana_database_init" {
  metadata {
    name      = "grafana-database-init"
    namespace = kubernetes_namespace_v1.monitoring.metadata[0].name
  }

  data = {
    "init.sql" = <<-SQL
      SELECT format('CREATE USER %I WITH PASSWORD %L', :'gusr', :'gpwd')
      WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'gusr')
      \gexec
      SELECT format('ALTER USER %I WITH PASSWORD %L', :'gusr', :'gpwd') \gexec
      SELECT format('CREATE SCHEMA IF NOT EXISTS %I AUTHORIZATION %I', :'gschema', :'gusr') \gexec
      SELECT format('ALTER SCHEMA %I OWNER TO %I', :'gschema', :'gusr') \gexec
      SELECT format('GRANT USAGE, CREATE ON SCHEMA %I TO %I', :'gschema', :'gusr') \gexec
      SELECT format('ALTER ROLE %I IN DATABASE %I SET search_path TO %I, public', :'gusr', :'gdb', :'gschema') \gexec
    SQL
  }
}

# Provision the dedicated 'grafana' role and schema inside the shared Postgres
# instance. The Job is rerun automatically when the password changes (via the
# replace_triggered_by lifecycle), and is idempotent on repeated runs: it
# creates the role+schema only when missing and always rewrites the password
# and search_path so the secret stays authoritative.
resource "kubernetes_job_v1" "grafana_database_init" {
  metadata {
    name      = "grafana-database-init"
    namespace = kubernetes_namespace_v1.monitoring.metadata[0].name
  }

  spec {
    backoff_limit = 5

    template {
      metadata {}
      spec {
        restart_policy = "OnFailure"

        container {
          name  = "psql"
          image = "postgres:18.4"

          env_from {
            secret_ref {
              name = kubernetes_secret_v1.grafana_database.metadata[0].name
            }
          }

          volume_mount {
            name       = "init-sql"
            mount_path = "/sql"
            read_only  = true
          }

          # The DDL lives in a ConfigMap and uses \gexec + format() so the
          # username, schema and password are quoted by Postgres rather than
          # spliced into SQL by string concatenation.
          command = ["/bin/sh", "-euc"]
          args = [
            "export PGPASSWORD=\"$PG_ADMIN_PASSWORD\"; exec psql -h \"$PG_HOST\" -p \"$PG_PORT\" -U \"$PG_ADMIN_USER\" -d \"$PG_DATABASE\" -v ON_ERROR_STOP=1 -v gusr=\"$GRAFANA_USER\" -v gpwd=\"$GRAFANA_PASSWORD\" -v gschema=\"$PG_SCHEMA\" -v gdb=\"$PG_DATABASE\" -f /sql/init.sql"
          ]
        }

        volume {
          name = "init-sql"
          config_map {
            name = kubernetes_config_map_v1.grafana_database_init.metadata[0].name
          }
        }
      }
    }
  }

  timeouts {
    create = "5m"
    update = "5m"
  }

  lifecycle {
    replace_triggered_by = [random_password.grafana_db_password]
  }
}

# kube-prometheus-stack bundles the Prometheus Operator together with
# Prometheus, Alertmanager, Grafana, node-exporter and kube-state-metrics. The
# Operator's CRDs (ServiceMonitor, PodMonitor, PrometheusRule, ...) are
# installed separately and earlier by setup_prometheus_operator_crds, because
# create_postgres_database — which this module depends on for Grafana's
# metadata — ships a ServiceMonitor and therefore needs the CRDs before this
# stack ever runs. crds.enabled is false here so the chart neither re-templates
# nor fights over ownership of those already-present CRDs.
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
      enabled = false
    }
    grafana = {
      service = {
        type = "ClusterIP"
        port = local.grafana_port
      }
      ingress = {
        enabled = false
      }
      # Fixed server-admin credentials (see locals). Setting these stops the
      # subchart from generating a random admin-password into the
      # kube-prometheus-stack-grafana Secret, so the value survives reprovisions
      # and a restored database backup stays consistent with the running config.
      adminUser     = local.grafana_admin_user
      adminPassword = local.grafana_admin_password
      # Persist Grafana's metadata (dashboards, folders, users, datasources,
      # ...) in the shared PostgreSQL so changes survive pod restarts and
      # chart upgrades. Grafana logs in as a dedicated role whose default
      # search_path points at the 'grafana' schema (set up by the init Job),
      # so its tables stay isolated from the apps that share the database.
      # Credentials are mounted from the secret to avoid baking them into the
      # rendered Helm values.
      envValueFrom = {
        GF_DATABASE_USER = {
          secretKeyRef = {
            name = kubernetes_secret_v1.grafana_database.metadata[0].name
            key  = "GRAFANA_USER"
          }
        }
        GF_DATABASE_PASSWORD = {
          secretKeyRef = {
            name = kubernetes_secret_v1.grafana_database.metadata[0].name
            key  = "GRAFANA_PASSWORD"
          }
        }
      }
      # The kiwigrid/k8s-sidecar containers (dashboards + datasources) talk
      # to the kube-apiserver over HTTPS using the in-cluster CA. MicroK8s'
      # CA cert is missing the keyUsage extension, which Python 3.14 +
      # OpenSSL 3 rejects ("CA cert does not include key usage extension"),
      # so the sidecars CrashLoopBackOff and the pod stays NotReady. The
      # API call stays inside the pod network on every node, so skipping
      # verification only widens the trust boundary to "anything that can
      # already reach the kube-apiserver", which is acceptable here.
      sidecar = {
        skipTlsVerify = true
      }
      # Trust the email header injected by oauth2-proxy. oauth2-proxy already
      # restricts sign-in to var.valid_email, so any request that reaches
      # Grafana with this header is the authorized user. auto_sign_up creates
      # the Grafana account on first login and auto_assign_org_role gives it
      # Admin so dashboards can be edited.
      "grafana.ini" = {
        # Pin the envelope-encryption / signing key so database secrets stay
        # decryptable across reprovisions and restores (see local.grafana_secret_key).
        security = {
          secret_key = local.grafana_secret_key
        }
        database = {
          type = "postgres"
          host = "${var.database.host}:${var.database.port}"
          name = var.database.name
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
        # Leave [auth.basic] at its default (enabled). The kiwigrid sidecars
        # call /api/admin/provisioning/{dashboards,datasources}/reload with
        # HTTP Basic Auth as the pinned admin user (adminUser/adminPassword
        # above); disabling basic auth makes those calls 401 and the bundled
        # Prometheus datasource never gets provisioned. External access is
        # already gated by the HTTPRoute in front of oauth2-proxy, so leaving
        # basic auth on doesn't widen the attack surface.
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
      # ClusterIP-only; external access happens through the HTTPRoute.
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

  # Wait for the grafana role + schema to exist before Grafana boots,
  # otherwise the pod's first connection fails authentication.
  depends_on = [kubernetes_job_v1.grafana_database_init]
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

resource "kubectl_manifest" "grafana_httproute" {
  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "grafana"
      namespace = kubernetes_namespace_v1.monitoring.metadata[0].name
    }
    spec = {
      parentRefs = [{
        name        = "traefik"
        namespace   = "traefik"
        sectionName = "websecure"
      }]
      hostnames = [var.grafana_hostname]
      rules = [{
        backendRefs = [{
          name = module.grafana_oauth2_proxy.service_name
          port = 80
        }]
      }]
    }
  })

  depends_on = [module.grafana_oauth2_proxy]
}

resource "kubectl_manifest" "prometheus_httproute" {
  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "prometheus"
      namespace = kubernetes_namespace_v1.monitoring.metadata[0].name
    }
    spec = {
      parentRefs = [{
        name        = "traefik"
        namespace   = "traefik"
        sectionName = "websecure"
      }]
      hostnames = [var.prometheus_hostname]
      rules = [{
        backendRefs = [{
          name = module.prometheus_oauth2_proxy.service_name
          port = 80
        }]
      }]
    }
  })

  depends_on = [module.prometheus_oauth2_proxy]
}
