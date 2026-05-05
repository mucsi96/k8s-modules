locals {
  port = 6379

  selector_labels = {
    "app.kubernetes.io/name"      = var.k8s_name
    "app.kubernetes.io/component" = "redis"
  }
}

resource "random_password" "password" {
  length  = 32
  special = false
}

resource "kubernetes_secret_v1" "auth" {
  metadata {
    name      = "${var.k8s_name}-auth"
    namespace = var.k8s_namespace
  }

  data = {
    redis-password = random_password.password.result
  }

  type = "Opaque"
}

resource "kubernetes_deployment_v1" "redis" {
  metadata {
    name      = var.k8s_name
    namespace = var.k8s_namespace
    labels    = local.selector_labels
  }

  spec {
    replicas = 1

    selector {
      match_labels = local.selector_labels
    }

    # Sessions live in the pod's tmpfs, so a rolling update would briefly
    # overlap two pods fighting for the same Service endpoint. Recreate
    # is fine here — losing in-flight sessions just means re-login.
    strategy {
      type = "Recreate"
    }

    template {
      metadata {
        labels = local.selector_labels
      }

      spec {
        container {
          name  = "redis"
          image = var.image

          command = ["redis-server"]
          args    = ["--requirepass", "$(REDIS_PASSWORD)"]

          env {
            name = "REDIS_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.auth.metadata[0].name
                key  = "redis-password"
              }
            }
          }

          port {
            name           = "redis"
            container_port = local.port
          }

          readiness_probe {
            tcp_socket {
              port = local.port
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }

          liveness_probe {
            tcp_socket {
              port = local.port
            }
            initial_delay_seconds = 30
            period_seconds        = 30
          }

          resources {
            requests = {
              cpu    = "10m"
              memory = "32Mi"
            }
            limits = {
              memory = "128Mi"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "redis" {
  metadata {
    name      = var.k8s_name
    namespace = var.k8s_namespace
    labels    = local.selector_labels
  }

  spec {
    type     = "ClusterIP"
    selector = local.selector_labels

    port {
      name        = "redis"
      port        = local.port
      target_port = "redis"
      protocol    = "TCP"
    }
  }
}
