locals {
  pgweb_name   = "pgweb"
  pgweb_port   = 8081
  database_url = "postgres://${var.database.username}:${urlencode(var.database.password)}@${var.database.host}:${var.database.port}/${var.database.name}?sslmode=disable"
}

resource "terraform_data" "wait_for" {
  input = var.wait_for
}

resource "kubernetes_namespace_v1" "pgweb" {
  metadata {
    name = "pgweb"
  }

  depends_on = [terraform_data.wait_for]
}

resource "kubernetes_secret_v1" "pgweb_db" {
  metadata {
    name      = "pgweb-db"
    namespace = kubernetes_namespace_v1.pgweb.metadata[0].name
  }

  data = {
    PGWEB_DATABASE_URL = local.database_url
  }
}

resource "kubernetes_deployment_v1" "pgweb" {
  metadata {
    name      = local.pgweb_name
    namespace = kubernetes_namespace_v1.pgweb.metadata[0].name
    labels = {
      app = local.pgweb_name
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = local.pgweb_name
      }
    }

    template {
      metadata {
        labels = {
          app = local.pgweb_name
        }
      }

      spec {
        container {
          name  = local.pgweb_name
          image = "sosedoff/pgweb:${var.pgweb_image_version}"

          # --lock-session prevents the user from disconnecting and reconnecting
          # to a different database via the UI; pgweb stays bound to the single
          # Postgres connection we configure here.
          args = [
            "--bind=0.0.0.0",
            "--listen=${local.pgweb_port}",
            "--lock-session",
          ]

          env {
            name = "PGWEB_DATABASE_URL"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.pgweb_db.metadata[0].name
                key  = "PGWEB_DATABASE_URL"
              }
            }
          }

          port {
            container_port = local.pgweb_port
            name           = "http"
          }

          readiness_probe {
            http_get {
              path = "/"
              port = local.pgweb_port
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }

          liveness_probe {
            http_get {
              path = "/"
              port = local.pgweb_port
            }
            initial_delay_seconds = 30
            period_seconds        = 30
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "pgweb" {
  metadata {
    name      = local.pgweb_name
    namespace = kubernetes_namespace_v1.pgweb.metadata[0].name
  }

  spec {
    type = "ClusterIP"
    selector = {
      app = local.pgweb_name
    }
    port {
      port        = 80
      target_port = local.pgweb_port
      protocol    = "TCP"
    }
  }
}

module "pgweb_oauth2_proxy" {
  source = "../setup_oauth2_proxy"

  name                       = local.pgweb_name
  namespace                  = kubernetes_namespace_v1.pgweb.metadata[0].name
  client_id                  = var.client_id
  client_secret              = var.client_secret
  tenant_id                  = var.tenant_id
  valid_email                = var.valid_email
  oauth2_proxy_chart_version = var.oauth2_proxy_chart_version
  oauth2_proxy_image_version = var.oauth2_proxy_image_version
  upstream_uri               = "http://${kubernetes_service_v1.pgweb.metadata[0].name}.${kubernetes_namespace_v1.pgweb.metadata[0].name}.svc.cluster.local:80"
  session_redis              = var.session_redis

  depends_on = [kubernetes_deployment_v1.pgweb]
}

resource "kubernetes_manifest" "pgweb_ingressroute" {
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "IngressRoute"
    metadata = {
      name      = "pgweb"
      namespace = kubernetes_namespace_v1.pgweb.metadata[0].name
    }
    spec = {
      entryPoints = ["web"]
      routes = [
        {
          match = "Host(`${var.hostname}`)"
          kind  = "Rule"
          services = [{
            name = module.pgweb_oauth2_proxy.service_name
            port = 80
          }]
        },
      ]
    }
  }

  depends_on = [module.pgweb_oauth2_proxy]
}
