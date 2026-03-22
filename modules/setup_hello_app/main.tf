locals {
  app_hostname = "hello.${var.hostname}"
}

module "app_base" {
  source = "../setup_app_base"

  github_repository          = "skeleton-app"
  environment_name           = var.environment_name
  app_name                   = "hello"
  azure_location             = var.azure_location
  tenant_id                  = var.tenant_id
  owner                      = var.owner
  twingate_service_key       = var.twingate_service_key
  k8s_host                   = var.k8s_host
  k8s_cluster_ca_certificate = var.k8s_cluster_ca_certificate
  app_hostname               = local.app_hostname
  api_client_id              = module.setup_hello_api.client_id
  api_client_secret          = module.setup_hello_api.client_secret
  spa_client_id              = module.setup_hello_spa.client_id
}

module "setup_hello_api" {
  source = "../register_api"
  owner  = var.owner

  display_name = "Hello API"
  roles        = ["GreetingReader", "GreetingCreator"]
  scopes       = ["readGreetings", "createGreeting"]

  k8s_oidc_issuer_url           = var.k8s_oidc_issuer_url
  k8s_service_account_namespace = "hello"
  k8s_service_account_name      = "hello-api-workload-identity"
}

module "setup_hello_spa" {
  source = "../register_spa"
  owner  = var.owner

  display_name  = "Hello SPA"
  redirect_uris = ["https://${local.app_hostname}/", "http://localhost:4200/"]

  api_id        = module.setup_hello_api.application_id
  api_client_id = module.setup_hello_api.client_id
  api_scope_ids = [
    module.setup_hello_api.scope_ids["readGreetings"],
    module.setup_hello_api.scope_ids["createGreeting"]
  ]
}

resource "kubernetes_persistent_volume_v1" "hello_app_pv" {
  metadata {
    name = "hello-app"
  }

  spec {
    storage_class_name = ""
    access_modes       = ["ReadWriteOnce"]
    capacity = {
      storage = "5Gi"
    }
    persistent_volume_reclaim_policy = "Retain"
    persistent_volume_source {
      host_path {
        path = "/data/hello"
      }
    }
  }
}

resource "kubernetes_persistent_volume_v1" "hello_backup_pv" {
  metadata {
    name = "hello-backup"
  }

  spec {
    storage_class_name = ""
    access_modes       = ["ReadWriteOnce"]
    capacity = {
      storage = "5Gi"
    }
    persistent_volume_reclaim_policy = "Retain"
    persistent_volume_source {
      host_path {
        path = "/data/hello"
      }
    }
  }
}
