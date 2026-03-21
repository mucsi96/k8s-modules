locals {
  app_hostname = "language.${var.hostname}"
}

module "create_learn_language_namespace" {
  source                     = "../create_app_namespace"
  environment_name           = var.environment_name
  k8s_namespace              = "learn-language"
  k8s_host                   = var.k8s_host
  k8s_cluster_ca_certificate = var.k8s_cluster_ca_certificate
}

module "setup_learn_language_api" {
  source = "../register_api"
  owner  = var.owner

  display_name = "Learn Language API"
  roles        = ["DeckReader", "DeckCreator"]
  scopes       = ["readDecks", "createDeck"]

  k8s_oidc_issuer_url           = var.k8s_oidc_issuer_url
  k8s_service_account_namespace = "learn-language"
  k8s_service_account_name      = "learn-language-api-workload-identity"
}

module "setup_learn_language_spa" {
  source = "../register_spa"
  owner  = var.owner

  display_name  = "Learn Language SPA"
  redirect_uris = ["https://${local.app_hostname}/", "http://localhost:4200/"]

  api_id        = module.setup_learn_language_api.application_id
  api_client_id = module.setup_learn_language_api.client_id
  api_scope_ids = [
    module.setup_learn_language_api.scope_ids["readDecks"],
    module.setup_learn_language_api.scope_ids["createDeck"]
  ]
}

resource "kubernetes_persistent_volume_v1" "learn_language_app_pv" {
  metadata {
    name = "learn-language-app"
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
        path = "/data/learn-language"
      }
    }
  }
}

resource "kubernetes_persistent_volume_v1" "learn_language_backup_pv" {
  metadata {
    name = "learn-language-backup"
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
        path = "/data/learn-language"
      }
    }
  }
}
