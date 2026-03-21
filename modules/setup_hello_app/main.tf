module "create_hello_namespace" {
  source                     = "../create_app_namespace"
  environment_name           = var.environment_name
  k8s_namespace              = "hello"
  k8s_host                   = var.k8s_host
  k8s_cluster_ca_certificate = var.k8s_cluster_ca_certificate
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
  redirect_uris = ["https://hello.${var.hostname}/", "http://localhost:4200/"]

  api_id        = module.setup_hello_api.application_id
  api_client_id = module.setup_hello_api.client_id
  api_scope_ids = [
    module.setup_hello_api.scope_ids["readGreetings"],
    module.setup_hello_api.scope_ids["createGreeting"]
  ]
}

resource "github_actions_secret" "twingate_service_key" {
  repository      = "skeleton-app"
  secret_name     = "TWINGATE_SERVICE_KEY"
  plaintext_value = var.twingate_service_key
}

resource "github_actions_secret" "k8s_config" {
  repository      = "skeleton-app"
  secret_name     = "K8S_CONFIG"
  plaintext_value = module.create_hello_namespace.k8s_user_config
}

resource "github_actions_secret" "hostname" {
  repository      = "skeleton-app"
  secret_name     = "HOSTNAME"
  plaintext_value = "hello.${var.hostname}"
}

resource "github_actions_secret" "api_client_id" {
  repository      = "skeleton-app"
  secret_name     = "API_CLIENT_ID"
  plaintext_value = module.setup_hello_api.client_id
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
