locals {
  app_hostname = "library.${var.hostname}"
}

module "postgres_schema" {
  source = "../setup_postgres_schema"

  database = var.database
  schema   = "library"
}

module "app_base" {
  source = "../setup_app_base"

  github_repository = "library-app"
  environment_name  = var.environment_name
  app_name          = "library"
  app_secrets = {
    openai-api-key = var.openai_api_key
  }
  azure_location         = var.azure_location
  tenant_id              = var.tenant_id
  azure_subscription_id  = var.azure_subscription_id
  owner                  = var.owner
  twingate_service_key   = var.twingate_service_key
  app_hostname           = local.app_hostname
  api_client_id          = module.setup_library_api.client_id
  api_client_secret      = module.setup_library_api.client_secret
  spa_client_id          = module.setup_library_spa.client_id
  api_resource_object_id = module.setup_library_api.resource_object_id
  k8s_oidc_config        = var.k8s_oidc_config
  client_log_url         = var.client_log_url
}

module "setup_library_api" {
  source = "../register_api"
  owner  = var.owner

  display_name = "Library API"
  roles        = ["LibraryUser"]
  scopes       = ["readItems", "writeItems"]

  k8s_oidc_issuer_url           = var.k8s_oidc_issuer_url
  k8s_service_account_namespace = "library"
  k8s_service_account_name      = "library-api-workload-identity"
}

module "setup_library_spa" {
  source = "../register_spa"
  owner  = var.owner

  display_name  = "Library SPA"
  redirect_uris = ["https://${local.app_hostname}/", "http://localhost:4250/"]

  api_id        = module.setup_library_api.application_id
  api_client_id = module.setup_library_api.client_id
  api_scope_ids = [
    module.setup_library_api.scope_ids["readItems"],
    module.setup_library_api.scope_ids["writeItems"]
  ]
}

resource "kubernetes_persistent_volume_v1" "library_app_pv" {
  metadata {
    name = "library-app"
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
        path = "/data/library"
      }
    }
  }
}

resource "kubernetes_persistent_volume_v1" "library_backup_pv" {
  metadata {
    name = "library-backup"
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
        path = "/data/library"
      }
    }
  }
}
