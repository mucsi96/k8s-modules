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

    github = {
      source  = "integrations/github"
      version = ">= 6.0.0"
    }

    docker = {
      source  = "docker/docker"
      version = ">= 0.2.0"
    }

    hcloud = {
      source  = "hetznercloud/hcloud"
      version = ">= 1.49.0"
    }
  }

  required_version = ">= 1.2"
}

# ── Variables ────────────────────────────────────────────────────────────────

variable "active_cluster" {
  description = "Which cluster the DNS points to: 'local' or 'hetzner'."
  type        = string
  default     = "local"

  validation {
    condition     = contains(["local", "hetzner"], var.active_cluster)
    error_message = "Must be 'local' or 'hetzner'."
  }
}

# ── Shared providers ────────────────────────────────────────────────────────

provider "random" {}

provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
}

provider "azuread" {}

provider "ansible" {}

provider "acme" {
  server_url = "https://acme-v02.api.letsencrypt.org/directory"
}

provider "cloudflare" {
  api_token = data.azurerm_key_vault_secret.cloudflare_api_token.value
}

provider "twingate" {
  api_token = data.azurerm_key_vault_secret.twingate_api_token.value
  network   = data.azurerm_key_vault_secret.twingate_network.value
}

provider "github" {
  owner = "mucsi96"
  token = data.azurerm_key_vault_secret.github_token.value
}

provider "docker" {}

data "azurerm_key_vault_secret" "hetzner_api_token" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "hetzner-api-token"
}

provider "hcloud" {
  token = data.azurerm_key_vault_secret.hetzner_api_token.value
}

# ── K8s/Helm providers for local cluster (default) ──────────────────────────

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

# ── K8s/Helm providers for Hetzner cluster ──────────────────────────────────

provider "kubernetes" {
  alias                  = "hetzner"
  host                   = module.setup_cluster_hetzner.k8s_host
  client_certificate     = module.setup_cluster_hetzner.k8s_client_certificate
  client_key             = module.setup_cluster_hetzner.k8s_client_key
  cluster_ca_certificate = module.setup_cluster_hetzner.k8s_cluster_ca_certificate
}

provider "helm" {
  alias = "hetzner"
  kubernetes {
    host                   = module.setup_cluster_hetzner.k8s_host
    client_certificate     = module.setup_cluster_hetzner.k8s_client_certificate
    client_key             = module.setup_cluster_hetzner.k8s_client_key
    cluster_ca_certificate = module.setup_cluster_hetzner.k8s_cluster_ca_certificate
  }
}

# ── Key Vault & shared secrets ──────────────────────────────────────────────

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

data "azurerm_key_vault_secret" "github_token" {
  key_vault_id = data.azurerm_key_vault.kv.id
  name         = "github-token"
}

data "azurerm_client_config" "current" {}

locals {
  owner = data.azurerm_client_config.current.object_id
  ingress_vars = {
    environment_name       = var.environment_name
    subscription_id        = var.azure_subscription_id
    dns_zone               = data.azurerm_key_vault_secret.dns_zone.value
    traefik_chart_version  = "37.1.2"
    traefik_version        = "v3.5.3"
    letsencrypt_email      = data.azurerm_key_vault_secret.letsencrypt_email.value
    cloudflare_api_token   = data.azurerm_key_vault_secret.cloudflare_api_token.value
    cloudflare_account_id  = data.azurerm_key_vault_secret.cloudflare_account_id.value
    cloudflare_zone_id     = data.azurerm_key_vault_secret.cloudflare_zone_id.value
    cloudflare_team_domain = data.azurerm_key_vault_secret.cloudflare_team_domain.value
    authorized_as          = data.azurerm_key_vault_secret.authorized_as.value
  }
}

# ── Hetzner server ──────────────────────────────────────────────────────────

module "hetzner_server" {
  source   = "./modules/hetzner_server"
  name     = "${var.environment_name}-k8s"
  username = "k8s"
}

# ── Cluster setup (both always provisioned) ─────────────────────────────────

module "setup_cluster" {
  source                = "./modules/setup_cluster"
  cluster_name          = "local"
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

module "setup_cluster_hetzner" {
  source                = "./modules/setup_cluster"
  cluster_name          = "hetzner"
  host                  = module.hetzner_server.host
  initial_port          = module.hetzner_server.initial_port
  username              = module.hetzner_server.username
  initial_password      = module.hetzner_server.initial_password
  azure_key_vault_name  = data.azurerm_key_vault.kv.name
  environment_name      = var.environment_name
  azure_subscription_id = var.azure_subscription_id
  storage_account_name  = var.storage_account_name
  azure_tenant_id       = data.azurerm_client_config.current.tenant_id
}

# ── Local cluster stack (uses default providers) ────────────────────────────

module "setup_ingress_controller" {
  source                  = "./modules/setup_ingress_controller"
  environment_name        = local.ingress_vars.environment_name
  subscription_id         = local.ingress_vars.subscription_id
  dns_zone                = local.ingress_vars.dns_zone
  traefik_chart_version   = local.ingress_vars.traefik_chart_version
  traefik_version         = local.ingress_vars.traefik_version
  letsencrypt_email       = local.ingress_vars.letsencrypt_email
  cloudflare_api_token    = local.ingress_vars.cloudflare_api_token
  cloudflare_account_id   = local.ingress_vars.cloudflare_account_id
  cloudflare_zone_id      = local.ingress_vars.cloudflare_zone_id
  cloudflare_team_domain  = local.ingress_vars.cloudflare_team_domain
  authorized_as           = local.ingress_vars.authorized_as
  manage_shared_resources = true
  manage_dns_record       = false
  depends_on              = [module.setup_cluster]
}

module "setup_twingate" {
  source             = "./modules/setup_twingate"
  environment_name   = var.environment_name
  twingate_network   = data.azurerm_key_vault_secret.twingate_network.value
  twingate_api_token = data.azurerm_key_vault_secret.twingate_api_token.value
  k8s_host           = data.azurerm_key_vault_secret.setup_cluster_host.value
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
  twingate_service_key       = module.setup_twingate.service_key
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
  twingate_service_key       = module.setup_twingate.service_key
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
  twingate_service_key       = module.setup_twingate.service_key
  wait_for                   = module.setup_ingress_controller.traefik_ready
}

module "setup_playwright_server" {
  source                     = "./modules/setup_playwright_server"
  environment_name           = var.environment_name
  k8s_host                   = module.setup_cluster.k8s_host
  k8s_cluster_ca_certificate = module.setup_cluster.k8s_cluster_ca_certificate
  playwright_version         = "1.52.0"
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
  twingate_service_key       = module.setup_twingate.service_key
  playwright_server_url      = module.setup_playwright_server.url
  wait_for                   = module.setup_ingress_controller.traefik_ready
}

# ── Hetzner cluster stack (uses aliased providers) ──────────────────────────

module "setup_ingress_controller_hetzner" {
  source = "./modules/setup_ingress_controller"
  providers = {
    kubernetes = kubernetes.hetzner
    helm       = helm.hetzner
    azurerm    = azurerm
    tls        = tls
    acme       = acme
    cloudflare = cloudflare
    random     = random
    azuread    = azuread
  }
  environment_name        = local.ingress_vars.environment_name
  subscription_id         = local.ingress_vars.subscription_id
  dns_zone                = local.ingress_vars.dns_zone
  traefik_chart_version   = local.ingress_vars.traefik_chart_version
  traefik_version         = local.ingress_vars.traefik_version
  letsencrypt_email       = local.ingress_vars.letsencrypt_email
  cloudflare_api_token    = local.ingress_vars.cloudflare_api_token
  cloudflare_account_id   = local.ingress_vars.cloudflare_account_id
  cloudflare_zone_id      = local.ingress_vars.cloudflare_zone_id
  cloudflare_team_domain  = local.ingress_vars.cloudflare_team_domain
  authorized_as           = local.ingress_vars.authorized_as
  cluster_name            = "hetzner"
  manage_shared_resources = false
  manage_dns_record       = false
  depends_on              = [module.setup_cluster_hetzner]
}

module "setup_twingate_hetzner" {
  source = "./modules/setup_twingate"
  providers = {
    twingate   = twingate
    kubernetes = kubernetes.hetzner
    helm       = helm.hetzner
  }
  environment_name   = var.environment_name
  twingate_network   = data.azurerm_key_vault_secret.twingate_network.value
  twingate_api_token = data.azurerm_key_vault_secret.twingate_api_token.value
  k8s_host           = module.hetzner_server.host
  depends_on         = [module.setup_cluster_hetzner]
}

module "create_database_namespace_hetzner" {
  source = "./modules/create_app_namespace"
  providers = {
    azurerm    = azurerm
    kubernetes = kubernetes.hetzner
  }
  environment_name = var.environment_name
  k8s_namespace    = "db"

  k8s_host                   = module.setup_cluster_hetzner.k8s_host
  k8s_cluster_ca_certificate = module.setup_cluster_hetzner.k8s_cluster_ca_certificate
  wait_for                   = module.setup_ingress_controller_hetzner.traefik_ready
}

module "create_database_hetzner" {
  source = "./modules/create_postgres_database"
  providers = {
    random = random
    helm   = helm.hetzner
  }
  k8s_name      = "postgres1"
  k8s_namespace = module.create_database_namespace_hetzner.k8s_namespace
  db_name       = "postgres1"
}

module "setup_backup_app_hetzner" {
  source = "./modules/setup_backup_app"
  providers = {
    random     = random
    azurerm    = azurerm
    azuread    = azuread
    github     = github
    docker     = docker
    kubernetes = kubernetes.hetzner
  }
  environment_name           = var.environment_name
  azure_location             = var.azure_location
  owner                      = local.owner
  k8s_host                   = module.setup_cluster_hetzner.k8s_host
  k8s_cluster_ca_certificate = module.setup_cluster_hetzner.k8s_cluster_ca_certificate
  k8s_oidc_issuer_url        = module.setup_cluster_hetzner.oidc_issuer_url
  hostname                   = data.azurerm_key_vault_secret.dns_zone.value
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  db_username                = module.create_database_hetzner.username
  db_password                = module.create_database_hetzner.password
  twingate_service_key       = module.setup_twingate_hetzner.service_key
  wait_for                   = module.setup_ingress_controller_hetzner.traefik_ready

  azure_storage_account_resource_group_name = "ibari"
  azure_storage_account_name                = "ibari"
}

module "setup_learn_language_app_hetzner" {
  source = "./modules/setup_learn_language_app"
  providers = {
    random     = random
    azurerm    = azurerm
    azuread    = azuread
    kubernetes = kubernetes.hetzner
    github     = github
    docker     = docker
  }
  environment_name           = var.environment_name
  azure_location             = var.azure_location
  owner                      = local.owner
  k8s_host                   = module.setup_cluster_hetzner.k8s_host
  k8s_cluster_ca_certificate = module.setup_cluster_hetzner.k8s_cluster_ca_certificate
  k8s_oidc_issuer_url        = module.setup_cluster_hetzner.oidc_issuer_url
  hostname                   = data.azurerm_key_vault_secret.dns_zone.value
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  db_jdbc_url                = module.create_database_hetzner.jdbc_url
  db_username                = module.create_database_hetzner.username
  db_password                = module.create_database_hetzner.password
  twingate_service_key       = module.setup_twingate_hetzner.service_key
  wait_for                   = module.setup_ingress_controller_hetzner.traefik_ready
}

module "setup_hello_app_hetzner" {
  source = "./modules/setup_hello_app"
  providers = {
    random     = random
    azurerm    = azurerm
    azuread    = azuread
    kubernetes = kubernetes.hetzner
    github     = github
    docker     = docker
  }
  environment_name           = var.environment_name
  azure_location             = var.azure_location
  owner                      = local.owner
  k8s_host                   = module.setup_cluster_hetzner.k8s_host
  k8s_cluster_ca_certificate = module.setup_cluster_hetzner.k8s_cluster_ca_certificate
  k8s_oidc_issuer_url        = module.setup_cluster_hetzner.oidc_issuer_url
  hostname                   = data.azurerm_key_vault_secret.dns_zone.value
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  db_jdbc_url                = module.create_database_hetzner.jdbc_url
  db_username                = module.create_database_hetzner.username
  db_password                = module.create_database_hetzner.password
  twingate_service_key       = module.setup_twingate_hetzner.service_key
  wait_for                   = module.setup_ingress_controller_hetzner.traefik_ready
}

module "setup_playwright_server_hetzner" {
  source = "./modules/setup_playwright_server"
  providers = {
    azurerm    = azurerm
    kubernetes = kubernetes.hetzner
  }
  environment_name           = var.environment_name
  k8s_host                   = module.setup_cluster_hetzner.k8s_host
  k8s_cluster_ca_certificate = module.setup_cluster_hetzner.k8s_cluster_ca_certificate
  playwright_version         = "1.52.0"
  wait_for                   = module.setup_ingress_controller_hetzner.traefik_ready
}

module "setup_training_log_app_hetzner" {
  source = "./modules/setup_training_log_app"
  providers = {
    random     = random
    azurerm    = azurerm
    azuread    = azuread
    kubernetes = kubernetes.hetzner
    github     = github
    docker     = docker
  }
  environment_name           = var.environment_name
  azure_location             = var.azure_location
  owner                      = local.owner
  k8s_host                   = module.setup_cluster_hetzner.k8s_host
  k8s_cluster_ca_certificate = module.setup_cluster_hetzner.k8s_cluster_ca_certificate
  k8s_oidc_issuer_url        = module.setup_cluster_hetzner.oidc_issuer_url
  hostname                   = data.azurerm_key_vault_secret.dns_zone.value
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  db_jdbc_url                = module.create_database_hetzner.jdbc_url
  db_username                = module.create_database_hetzner.username
  db_password                = module.create_database_hetzner.password
  twingate_service_key       = module.setup_twingate_hetzner.service_key
  playwright_server_url      = module.setup_playwright_server_hetzner.url
  wait_for                   = module.setup_ingress_controller_hetzner.traefik_ready
}

# ── DNS switching ───────────────────────────────────────────────────────────

resource "cloudflare_dns_record" "active_cname" {
  zone_id = data.azurerm_key_vault_secret.cloudflare_zone_id.value
  name    = "*"
  content = "${var.active_cluster == "hetzner" ? module.setup_ingress_controller_hetzner.tunnel_id : module.setup_ingress_controller.tunnel_id}.cfargotunnel.com"
  type    = "CNAME"
  ttl     = 1
  proxied = true
}

# ── State moves (count additions to existing resources) ─────────────────────

moved {
  from = module.setup_ingress_controller.cloudflare_dns_record.cname_record
  to   = cloudflare_dns_record.active_cname
}

moved {
  from = module.setup_ingress_controller.cloudflare_ruleset.firewall_rules
  to   = module.setup_ingress_controller.cloudflare_ruleset.firewall_rules[0]
}

moved {
  from = module.setup_ingress_controller.cloudflare_ruleset.rate_limiting
  to   = module.setup_ingress_controller.cloudflare_ruleset.rate_limiting[0]
}

moved {
  from = module.setup_ingress_controller.azuread_service_principal.msgraph
  to   = module.setup_ingress_controller.azuread_service_principal.msgraph[0]
}

moved {
  from = module.setup_ingress_controller.azuread_application.cloudflare_sso
  to   = module.setup_ingress_controller.azuread_application.cloudflare_sso[0]
}

moved {
  from = module.setup_ingress_controller.azuread_service_principal.cloudflare_sso
  to   = module.setup_ingress_controller.azuread_service_principal.cloudflare_sso[0]
}

moved {
  from = module.setup_ingress_controller.azuread_service_principal_delegated_permission_grant.allow_cloudflare_sso_to_access_msgraph_user_profile
  to   = module.setup_ingress_controller.azuread_service_principal_delegated_permission_grant.allow_cloudflare_sso_to_access_msgraph_user_profile[0]
}

moved {
  from = module.setup_ingress_controller.azuread_application_password.cloudflare_sso
  to   = module.setup_ingress_controller.azuread_application_password.cloudflare_sso[0]
}

moved {
  from = module.setup_ingress_controller.cloudflare_zero_trust_access_identity_provider.entra_id
  to   = module.setup_ingress_controller.cloudflare_zero_trust_access_identity_provider.entra_id[0]
}

moved {
  from = module.setup_ingress_controller.cloudflare_zero_trust_access_policy.cloudflare_sso
  to   = module.setup_ingress_controller.cloudflare_zero_trust_access_policy.cloudflare_sso[0]
}

moved {
  from = module.setup_ingress_controller.cloudflare_zero_trust_access_application.traefik_dashboard_access
  to   = module.setup_ingress_controller.cloudflare_zero_trust_access_application.traefik_dashboard_access[0]
}
