locals {
  app_name      = "playwright-server"
  k8s_namespace = "playwright"
  port          = 3000
}

module "create_namespace" {
  source                     = "../create_app_namespace"
  environment_name           = var.environment_name
  k8s_namespace              = local.k8s_namespace
  k8s_host                   = var.k8s_host
  k8s_cluster_ca_certificate = var.k8s_cluster_ca_certificate
  wait_for                   = var.wait_for
}

resource "kubernetes_deployment_v1" "playwright_server" {
  metadata {
    name      = local.app_name
    namespace = module.create_namespace.k8s_namespace
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
    namespace = module.create_namespace.k8s_namespace
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
