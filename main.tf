terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.14.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">=2.35.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = ">=2.16.1"
    }

    tls = {
      source  = "hashicorp/tls"
      version = ">=4.0.6"
    }

    acme = {
      source  = "vancluever/acme"
      version = ">= 2.28.2"
    }

    ansible = {
      source  = "ansible/ansible"
      version = ">= 1.3.0"
    }

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.18.0"
    }

    twingate = {
      source  = "Twingate/twingate"
      version = "4.0.2"
    }
  }

  required_version = ">= 1.2"
}

provider "random" {}

provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
}

provider "azuread" {}

provider "ansible" {}



provider "kubernetes" {
  host                   = module.setup_cluster.k8s_host
  client_certificate     = module.setup_cluster.k8s_client_certificate
  client_key             = module.setup_cluster.k8s_client_key
  cluster_ca_certificate = module.setup_cluster.k8s_cluster_ca_certificate
}

provider "helm" {
  kubernetes = {
    host                   = module.setup_cluster.k8s_host
    client_certificate     = module.setup_cluster.k8s_client_certificate
    client_key             = module.setup_cluster.k8s_client_key
    cluster_ca_certificate = module.setup_cluster.k8s_cluster_ca_certificate
  }
}

provider "acme" {
  # server_url = "https://acme-staging-v02.api.letsencrypt.org/directory" # Staging server
  server_url = "https://acme-v02.api.letsencrypt.org/directory" # Production server
}

provider "cloudflare" {
  api_token = data.azurerm_key_vault_secret.cloudflare_api_token.value
}

provider "twingate" {
  api_token = data.azurerm_key_vault_secret.twingate_api_token.value
  network   = data.azurerm_key_vault_secret.twingate_network.value
}

data "azurerm_key_vault" "kv" {
  resource_group_name = var.environment_name
  name                = var.environment_name
}

data "azurerm_key_vault_secret" "setup_cluster_host" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "host"
}

data "azurerm_key_vault_secret" "setup_cluster_username" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "ssh-user-name"
}

data "azurerm_key_vault_secret" "setup_cluster_initial_password" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "ssh-initial-password"
}

data "azurerm_key_vault_secret" "setup_cluster_initial_port" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "ssh-initial-port"
}

module "setup_cluster" {
  source                = "./modules/setup_cluster"
  host                  = data.azurerm_key_vault_secret.setup_cluster_host.value
  initial_port          = tonumber(data.azurerm_key_vault_secret.setup_cluster_initial_port.value)
  username              = data.azurerm_key_vault_secret.setup_cluster_username.value
  initial_password      = data.azurerm_key_vault_secret.setup_cluster_initial_password.value
  azure_key_vault_name  = data.azurerm_key_vault.kv.name
  environment_name      = var.environment_name
  azure_subscription_id = var.azure_subscription_id
  storage_account_name  = var.storage_account_name
  azure_tenant_id       = data.azurerm_client_config.current.tenant_id
}

data "azurerm_key_vault_secret" "dns_zone" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "dns-zone"
}

data "azurerm_key_vault_secret" "letsencrypt_email" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "letsencrypt-email"
}

data "azurerm_key_vault_secret" "cloudflare_zone_id" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "cloudflare-zone-id"
}

data "azurerm_key_vault_secret" "cloudflare_account_id" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "cloudflare-account-id"
}

data "azurerm_key_vault_secret" "cloudflare_api_token" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "cloudflare-api-token"
}

data "azurerm_key_vault_secret" "cloudflare_team_domain" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "cloudflare-team-domain"
}

data "azurerm_key_vault_secret" "authorized_as" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "authorized-as"
}

data "azurerm_key_vault_secret" "twingate_api_token" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "twingate-api-token"
}

data "azurerm_key_vault_secret" "twingate_network" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "twingate-network"
}

module "setup_ingress_controller" {
  source                 = "./modules/setup_ingress_controller"
  environment_name       = var.environment_name
  subscription_id        = var.azure_subscription_id
  dns_zone               = data.azurerm_key_vault_secret.dns_zone.value
  traefik_chart_version  = "37.1.2" #https://github.com/traefik/traefik-helm-chart/releases
  traefik_version        = "v3.5.3" #https://github.com/traefik/traefik/releases
  letsencrypt_email      = data.azurerm_key_vault_secret.letsencrypt_email.value
  cloudflare_api_token   = data.azurerm_key_vault_secret.cloudflare_api_token.value
  cloudflare_account_id  = data.azurerm_key_vault_secret.cloudflare_account_id.value
  cloudflare_zone_id     = data.azurerm_key_vault_secret.cloudflare_zone_id.value
  cloudflare_team_domain = data.azurerm_key_vault_secret.cloudflare_team_domain.value
  authorized_as          = data.azurerm_key_vault_secret.authorized_as.value
  depends_on             = [module.setup_cluster]
}

module "setup_twingate" {
  source             = "./modules/setup_twingate"
  environment_name   = var.environment_name
  twingate_network   = data.azurerm_key_vault_secret.twingate_network.value
  twingate_api_token = data.azurerm_key_vault_secret.twingate_api_token.value
  k8s_host           = data.azurerm_key_vault_secret.setup_cluster_host.value
  app_names          = ["backup", "learn-language", "hello", "training-log", "film", "reading-tracker"]
  depends_on         = [module.setup_cluster]
}

module "create_database_namespace" {
  source           = "./modules/create_app_namespace"
  environment_name = var.environment_name
  k8s_namespace    = "db"

  k8s_host                   = module.setup_cluster.k8s_host
  k8s_cluster_ca_certificate = module.setup_cluster.k8s_cluster_ca_certificate
  wait_for                   = module.setup_ingress_controller.traefik_ready
}

module "create_database" {
  source        = "./modules/create_postgres_database"
  k8s_name      = "postgres1"
  k8s_namespace = module.create_database_namespace.k8s_namespace
  db_name       = "postgres1"
}

data "azurerm_client_config" "current" {}

locals {
  owner = data.azurerm_client_config.current.object_id
}

module "setup_backup_app" {
  source                     = "./modules/setup_backup_app"
  environment_name           = var.environment_name
  azure_location             = var.azure_location
  owner                      = local.owner
  k8s_host                   = module.setup_cluster.k8s_host
  k8s_cluster_ca_certificate = module.setup_cluster.k8s_cluster_ca_certificate
  k8s_oidc_issuer_url        = module.setup_cluster.oidc_issuer_url
  hostname                   = data.azurerm_key_vault_secret.dns_zone.value
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  db_username                = module.create_database.username
  db_password                = module.create_database.password
  twingate_service_key       = module.setup_twingate.service_keys["backup"]
  wait_for                   = module.setup_ingress_controller.traefik_ready

  azure_storage_account_resource_group_name = "ibari"
  azure_storage_account_name                = "ibari"
}

module "setup_learn_language_app" {
  source                     = "./modules/setup_learn_language_app"
  environment_name           = var.environment_name
  azure_location             = var.azure_location
  owner                      = local.owner
  k8s_host                   = module.setup_cluster.k8s_host
  k8s_cluster_ca_certificate = module.setup_cluster.k8s_cluster_ca_certificate
  k8s_oidc_issuer_url        = module.setup_cluster.oidc_issuer_url
  hostname                   = data.azurerm_key_vault_secret.dns_zone.value
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  db_jdbc_url                = module.create_database.jdbc_url
  db_username                = module.create_database.username
  db_password                = module.create_database.password
  twingate_service_key       = module.setup_twingate.service_keys["learn-language"]
  wait_for                   = module.setup_ingress_controller.traefik_ready
}

module "setup_hello_app" {
  source                     = "./modules/setup_hello_app"
  environment_name           = var.environment_name
  azure_location             = var.azure_location
  owner                      = local.owner
  k8s_host                   = module.setup_cluster.k8s_host
  k8s_cluster_ca_certificate = module.setup_cluster.k8s_cluster_ca_certificate
  k8s_oidc_issuer_url        = module.setup_cluster.oidc_issuer_url
  hostname                   = data.azurerm_key_vault_secret.dns_zone.value
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  db_jdbc_url                = module.create_database.jdbc_url
  db_username                = module.create_database.username
  db_password                = module.create_database.password
  twingate_service_key       = module.setup_twingate.service_keys["hello"]
  wait_for                   = module.setup_ingress_controller.traefik_ready
}

module "setup_training_log_app" {
  source                     = "./modules/setup_training_log_app"
  environment_name           = var.environment_name
  azure_location             = var.azure_location
  owner                      = local.owner
  k8s_host                   = module.setup_cluster.k8s_host
  k8s_cluster_ca_certificate = module.setup_cluster.k8s_cluster_ca_certificate
  k8s_oidc_issuer_url        = module.setup_cluster.oidc_issuer_url
  hostname                   = data.azurerm_key_vault_secret.dns_zone.value
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  db_jdbc_url                = module.create_database.jdbc_url
  db_username                = module.create_database.username
  db_password                = module.create_database.password
  twingate_service_key       = module.setup_twingate.service_keys["training-log"]
  wait_for                   = module.setup_ingress_controller.traefik_ready
}

module "setup_film_app" {
  source                     = "./modules/setup_film_app"
  environment_name           = var.environment_name
  azure_location             = var.azure_location
  owner                      = local.owner
  k8s_host                   = module.setup_cluster.k8s_host
  k8s_cluster_ca_certificate = module.setup_cluster.k8s_cluster_ca_certificate
  k8s_oidc_issuer_url        = module.setup_cluster.oidc_issuer_url
  hostname                   = data.azurerm_key_vault_secret.dns_zone.value
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  db_jdbc_url                = module.create_database.jdbc_url
  db_username                = module.create_database.username
  db_password                = module.create_database.password
  twingate_service_key       = module.setup_twingate.service_keys["film"]
  wait_for                   = module.setup_ingress_controller.traefik_ready
}

module "setup_reading_tracker_app" {
  source                     = "./modules/setup_reading_tracker_app"
  environment_name           = var.environment_name
  azure_location             = var.azure_location
  owner                      = local.owner
  k8s_host                   = module.setup_cluster.k8s_host
  k8s_cluster_ca_certificate = module.setup_cluster.k8s_cluster_ca_certificate
  k8s_oidc_issuer_url        = module.setup_cluster.oidc_issuer_url
  hostname                   = data.azurerm_key_vault_secret.dns_zone.value
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  db_jdbc_url                = module.create_database.jdbc_url
  db_username                = module.create_database.username
  db_password                = module.create_database.password
  twingate_service_key       = module.setup_twingate.service_keys["reading-tracker"]
  wait_for                   = module.setup_ingress_controller.traefik_ready
}
