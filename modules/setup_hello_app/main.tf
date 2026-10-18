locals {
  app_hostname = "hello.${var.hostname}"
}

module "postgres_schema" {
  source = "../setup_postgres_schema"

  database = var.database
  schema   = "hello"
}

module "app_base" {
  source = "../setup_app_base"

  github_repository = "skeleton-app"
  environment_name  = var.environment_name
  app_name          = "hello"
  app_secrets = {
    claude-api-key = var.claude_api_key
  }
  deployment_secrets = {
    forward-auth-config = jsonencode(module.forward_auth.deployment_config)
  }
  azure_location         = var.azure_location
  tenant_id              = var.tenant_id
  azure_subscription_id  = var.azure_subscription_id
  owner                  = var.owner
  twingate_service_key   = var.twingate_service_key
  app_hostname           = local.app_hostname
  api_client_id          = module.setup_hello_api.client_id
  api_client_secret      = module.setup_hello_api.client_secret
  spa_client_id          = module.setup_hello_web.client_id
  api_resource_object_id = module.setup_hello_api.resource_object_id
  k8s_oidc_config        = var.k8s_oidc_config
  client_log_url         = var.client_log_url
}

module "setup_hello_api" {
  source = "../register_api"
  owner  = var.owner

  display_name = "Hello API"
  roles        = ["readGreetings", "createGreeting"]

  k8s_oidc_issuer_url           = var.k8s_oidc_issuer_url
  k8s_service_account_namespace = "hello"
  k8s_service_account_name      = "hello-api-workload-identity"
}

module "setup_hello_web" {
  source = "../register_web"
  owner  = var.owner

  display_name  = "Hello Web"
  redirect_uris = ["https://${local.app_hostname}/oauth2/callback"]
  api_access = {
    application_id = module.setup_hello_api.application_id
    client_id      = module.setup_hello_api.client_id
    scope_id       = module.setup_hello_api.scope_id
  }
}

module "forward_auth" {
  source = "../setup_app_forwardauth"

  name                = "hello"
  namespace           = module.app_base.namespace
  hostname            = local.app_hostname
  tenant_id           = var.tenant_id
  client_id           = module.setup_hello_web.client_id
  client_secret       = module.setup_hello_web.client_secret
  api_client_id       = module.setup_hello_api.client_id
  trusted_proxy_cidrs = nonsensitive(var.forward_auth.trusted_proxy_cidrs)
  session_redis       = var.forward_auth.session_redis
  gateway_parent_ref  = var.forward_auth.gateway_parent_ref
  excluded_routes = [{
    path    = "/api/environment"
    method  = "GET"
    service = "hello-server"
    port    = 8080
  }]
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
