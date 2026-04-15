locals {
  app_name = "playwright-server"
  port     = 3000
}

resource "kubernetes_deployment_v1" "playwright_server" {
  metadata {
    name      = local.app_name
    namespace = var.k8s_namespace
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = local.app_name
      }
    }

    template {
      metadata {
        labels = {
          app = local.app_name
        }
      }

      spec {
        container {
          name  = local.app_name
          image = "mcr.microsoft.com/playwright:v${var.playwright_version}"

          command = ["npx", "playwright", "run-server", "--port", tostring(local.port), "--host", "0.0.0.0"]

          port {
            container_port = local.port
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "playwright_server" {
  metadata {
    name      = local.app_name
    namespace = var.k8s_namespace
  }

  spec {
    selector = {
      app = local.app_name
    }

    port {
      port        = local.port
      target_port = local.port
    }
  }
}
