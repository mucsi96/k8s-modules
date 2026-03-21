locals {
  app_hostname = "training.${var.hostname}"
}

module "create_training_log_namespace" {
  source                     = "../create_app_namespace"
  environment_name           = var.environment_name
  k8s_namespace              = "training-log"
  k8s_host                   = var.k8s_host
  k8s_cluster_ca_certificate = var.k8s_cluster_ca_certificate
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
