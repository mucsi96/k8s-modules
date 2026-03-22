locals {
  app_hostname = "training.${var.hostname}"
}

module "app_base" {
  source = "../setup_app_base"

  github_repository          = "training-log-pro"
  environment_name           = var.environment_name
  app_name                   = "training-log"
  azure_location             = var.azure_location
  tenant_id                  = var.tenant_id
  owner                      = var.owner
  twingate_service_key       = var.twingate_service_key
  k8s_host                   = var.k8s_host
  k8s_cluster_ca_certificate = var.k8s_cluster_ca_certificate
  app_hostname               = local.app_hostname
  api_client_id              = module.setup_training_log_api.client_id
  api_client_secret          = module.setup_training_log_api.client_secret
  spa_client_id              = module.setup_training_log_spa.client_id
}

module "setup_training_log_api" {
  source = "../register_api"
  owner  = var.owner

  display_name = "Training Log API"
  roles        = ["WorkoutReader", "WorkoutCreator"]
  scopes       = ["readWorkouts", "createWorkout"]

  k8s_oidc_issuer_url           = var.k8s_oidc_issuer_url
  k8s_service_account_namespace = "training-log"
  k8s_service_account_name      = "training-log-api-workload-identity"
}

module "setup_training_log_spa" {
  source = "../register_spa"
  owner  = var.owner

  display_name  = "Training Log SPA"
  redirect_uris = ["https://${local.app_hostname}/", "http://localhost:4200/"]

  api_id        = module.setup_training_log_api.application_id
  api_client_id = module.setup_training_log_api.client_id
  api_scope_ids = [
    module.setup_training_log_api.scope_ids["readWorkouts"],
    module.setup_training_log_api.scope_ids["createWorkout"]
  ]
}

resource "kubernetes_persistent_volume_v1" "training_log_app_pv" {
  metadata {
    name = "training-log-app"
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
        path = "/data/training-log"
      }
    }
  }
}

resource "kubernetes_persistent_volume_v1" "training_log_backup_pv" {
  metadata {
    name = "training-log-backup"
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
        path = "/data/training-log"
      }
    }
  }
}
