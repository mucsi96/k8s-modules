locals {
  release_name = "victoria-metrics-k8s-stack"
  # Service created by the chart for the Grafana subchart.
  grafana_service_name = "${local.release_name}-grafana"
  grafana_port         = 80
  email_header_name    = "X-Auth-Request-Email"

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
  grafana_admin_password = "123"

  # Static key for Grafana's envelope encryption and signed settings. Pinned so
  # secrets stored in the database (datasource credentials, the data_keys table)
  # stay decryptable across reprovisions and restores. The subchart otherwise
  # leaves this at Grafana's well-known built-in default value.
  grafana_secret_key = "123"
}

module "postgres_schema" {
  source = "../setup_postgres_schema"

  database = var.database
  schema   = "grafana"
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
    GRAFANA_USER     = module.postgres_schema.credentials.username
    GRAFANA_PASSWORD = module.postgres_schema.credentials.password
  }

  type = "Opaque"
}

# victoria-metrics-k8s-stack replaces Prometheus with VictoriaMetrics as the
# metrics store: VMSingle stores the time series (a fraction of Prometheus'
# RAM for the same workload), vmagent scrapes targets, and VMAlert evaluates
# the recording rules Grafana dashboards rely on. Grafana, node-exporter and
# kube-state-metrics stay as the same subcharts kube-prometheus-stack used.
#
# The VM operator converts Prometheus Operator objects (ServiceMonitor,
# PodMonitor, ...) into its own VMServiceScrape / VMPodMonitor equivalents, so
# the ServiceMonitors shipped by postgres-db and the app modules keep
# working untouched - that is why the monitoring CRDs must still be installed
# first (setup_monitoring_crds) and stay in place.
# crds.plain (default true) installs the VictoriaMetrics operator CRDs as part
# of this release; the Prometheus CRDs are NOT removed by it.
resource "helm_release" "victoria_metrics_k8s_stack" {
  name       = local.release_name
  repository = "https://victoriametrics.github.io/helm-charts"
  chart      = "victoria-metrics-k8s-stack"
  version    = var.victoria_metrics_k8s_stack_chart_version
  namespace  = kubernetes_namespace_v1.monitoring.metadata[0].name
  wait       = true
  timeout    = 600

  values = [yamlencode({
    # Resources of the victoria-metrics-operator subchart deployment (top-level
    # `resources` key in that chart; the `operator` block only holds feature flags).
    "victoria-metrics-operator" = {
      # Keep the pre-delete cleanup hook's label below Kubernetes' 63-byte limit.
      fullnameOverride = "vm-operator"
      resources = {
        requests = {
          cpu    = "10m"
          memory = "64Mi"
        }
        limits = {
          memory = "128Mi"
        }
      }
    }
    vmsingle = {
      enabled = true
      spec = {
        # 3d retention (down from 10d) cuts the stored time series to ~30%.
        # VictoriaMetrics drops out-of-retention samples at ingestion and
        # deletes old parts continuously. Days are the finest granularity the
        # open-source build supports.
        retentionPeriod = "3d"
        extraArgs = {
          # VictoriaMetrics has no size cap equivalent to Prometheus'
          # retentionSize; this is the safety net: when free disk space drops
          # below 10GiB the storage goes read-only instead of filling the
          # disk. Ample headroom on the 256 GB disk. The flag takes a raw
          # byte count (10 * 1024^3) — Kubernetes-style quantities like
          # "10Gi" fail to parse and crash-loop the container on startup.
          "storage.minFreeDiskSpaceBytes" = "10737418240"
          # Caps the share of the container's memory limit VM may use for
          # caches/index blocks (default 60%). Most of the ~460Mi working set
          # was cache, so dropping to 40% trims idle RAM without touching
          # ingestion; the trade-off is slightly more frequent cache misses.
          "memory.allowedPercent" = "40"
        }
        storage = {
          accessModes = ["ReadWriteOnce"]
          resources = {
            requests = {
              storage = "20Gi"
            }
          }
        }
        # Sized from observed usage (~52m / ~459Mi).
        resources = {
          requests = {
            cpu    = "60m"
            memory = "512Mi"
          }
          limits = {
            memory = "1Gi"
          }
        }
      }
    }
    vmagent = {
      enabled = true
      spec = {
        # 60s (down from 30s) halves the sample volume; on a single node with
        # low-churn workloads the finer resolution buys nothing. Combined with
        # the retention cut this drops RAM from ~680Mi to well under 300Mi
        # across VMSingle + VMAgent.
        scrapeInterval = "60s"
        extraArgs = {
          "promscrape.streamParse" = "true"
        }
        # Sized from observed usage (~25m / ~139Mi).
        resources = {
          requests = {
            cpu    = "25m"
            memory = "160Mi"
          }
          limits = {
            memory = "512Mi"
          }
        }
      }
    }
    vmalert = {
      enabled = true
      spec = {
        evaluationInterval = "60s"
        extraArgs = {
          "http.pathPrefix" = "/"
          # No alert receivers exist anywhere in this setup (Alertmanager is
          # disabled below), so vmalert is told to blackhole notifications
          # instead of failing validation without any notifier.
          "notifier.blackhole" = "true"
        }
        resources = {
          requests = {
            cpu    = "10m"
            memory = "64Mi"
          }
          limits = {
            memory = "256Mi"
          }
        }
      }
    }
    # No alert receivers are configured anywhere in this setup, so
    # Alertmanager would only sit idle collecting firing alerts nobody sees.
    # vmalert still evaluates the VMRules (Grafana dashboards use their
    # recording rules); re-enable this if alert delivery is ever set up.
    alertmanager = {
      enabled = false
    }
    # Keep only the targets that exist and matter on a single-node k3s:
    # kubelet, node-exporter, kube-state-metrics, coredns and the API server.
    # The controller-manager, scheduler, proxy and etcd either don't exist as
    # separate k3s pods or don't expose metrics, so each one is a dead target
    # producing scrape errors and noise (plus rule groups and dashboards).
    kubeApiServer = {
      enabled = true
    }
    kubelet = {
      enabled = true
    }
    coreDns = {
      enabled = true
    }
    kubeControllerManager = {
      enabled = false
    }
    kubeScheduler = {
      enabled = false
    }
    kubeProxy = {
      enabled = false
    }
    kubeEtcd = {
      enabled = false
    }
    # Provision the datasource under the same name and UID kube-prometheus-stack
    # used ("Prometheus" / "prometheus") but pointed at VMSingle, so existing
    # dashboards in the persisted Grafana database keep resolving it. timeInterval
    # matches the 60s scrape interval so Grafana doesn't request more resolution
    # than was stored.
    defaultDatasources = {
      victoriametrics = {
        datasources = [{
          name      = "Prometheus"
          type      = "prometheus"
          access    = "proxy"
          uid       = "prometheus"
          isDefault = true
          jsonData = {
            timeInterval = "60s"
          }
        }]
      }
    }
    # VictoriaLogs single-node store. The log pipeline (Alloy, deployed by
    # setup_victoria_logs) ships pod logs and Faro browser telemetry to its
    # Loki-compatible push API, replacing the standalone Loki release. VL is
    # dramatically lighter than Loki's ingester, which buffers chunks in RAM.
    vlsingle = {
      enabled = true
      spec = {
        # Matches the 168h (7d) retention the Loki release used, so disk usage
        # stays bounded the same way.
        retentionPeriod = "7d"
        storage = {
          accessModes = ["ReadWriteOnce"]
          resources = {
            requests = {
              storage = "20Gi"
            }
          }
        }
        # Sized from observed usage (~10m / ~52Mi): the request tracks the
        # real working set instead of the previous 128Mi guess.
        resources = {
          requests = {
            cpu    = "10m"
            memory = "64Mi"
          }
          limits = {
            memory = "512Mi"
          }
        }
      }
    }
    # Grafana plugin for querying VictoriaLogs (LogsQL). The stack provisions
    # the matching "VictoriaLogs (DS)" datasource pointing at VLSingle once
    # vlsingle is enabled; without the plugin installed that datasource is
    # broken. The plugin is fetched from grafana.com when the Grafana pod
    # starts, so the pod needs internet access on first boot.
    grafana = {
      plugins = ["victoriametrics-logs-datasource"]
      service = {
        type = "ClusterIP"
        port = local.grafana_port
      }
      ingress = {
        enabled = false
      }
      # Fixed server-admin credentials (see locals). Setting these stops the
      # subchart from generating a random admin-password into the
      # victoria-metrics-k8s-stack-grafana Secret, so the value survives
      # reprovisions and a restored database backup stays consistent with the
      # running config.
      adminUser     = local.grafana_admin_user
      adminPassword = local.grafana_admin_password
      # Pin Grafana's envelope-encryption / signing key via the environment
      # rather than in grafana.ini: the chart's assertNoLeakedSecrets guard
      # rejects sensitive keys (secret_key, admin_password, ...) written
      # literally into grafana.ini. GF_SECURITY_SECRET_KEY maps to
      # [security] secret_key and keeps database secrets (datasource
      # credentials, the data_keys table) decryptable across reprovisions and
      # restores (see local.grafana_secret_key).
      env = {
        GF_SECURITY_SECRET_KEY = local.grafana_secret_key
      }
      # Persist Grafana's metadata (dashboards, folders, users, datasources,
      # ...) in the shared PostgreSQL so changes survive pod restarts and
      # chart upgrades. Grafana logs in as a dedicated role whose default
      # search_path points at its owned 'grafana' schema, so its tables stay
      # isolated from the apps that share the database.
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
      sidecar = {
        # Applies to both kiwigrid/k8s-sidecar containers (sc-dashboard and
        # sc-datasources); each idles around 80Mi watching ConfigMaps.
        resources = {
          requests = {
            cpu    = "5m"
            memory = "96Mi"
          }
          limits = {
            memory = "128Mi"
          }
        }
      }
      # Sized from observed usage (~59m / ~286Mi): the working set settled
      # back down after the dashboard/plugin churn, so the request tracks it
      # again and the limit stays a comfortable margin above.
      resources = {
        requests = {
          cpu    = "60m"
          memory = "288Mi"
        }
        limits = {
          memory = "640Mi"
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
        # datasource never gets provisioned. External access is
        # already gated by the HTTPRoute in front of oauth2-proxy, so leaving
        # basic auth on doesn't widen the attack surface.
        users = {
          auto_assign_org      = true
          auto_assign_org_role = "Admin"
          allow_sign_up        = false
        }
      }
    }
    "kube-state-metrics" = {
      resources = {
        requests = {
          cpu    = "10m"
          memory = "48Mi"
        }
        limits = {
          memory = "128Mi"
        }
      }
    }
    "prometheus-node-exporter" = {
      resources = {
        requests = {
          cpu    = "10m"
          memory = "48Mi"
        }
        limits = {
          memory = "128Mi"
        }
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

  depends_on = [helm_release.victoria_metrics_k8s_stack]
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
        group       = "gateway.networking.k8s.io"
        kind        = "Gateway"
        name        = var.gateway_parent_ref.name
        namespace   = var.gateway_parent_ref.namespace
        sectionName = var.gateway_parent_ref.section_name
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
