data "azuread_client_config" "current" {}

module "cloudflare_sso_app" {
  source = "../register_web_app"

  display_name             = "Cloudflare SSO - ${var.environment_name}"
  owner                    = data.azuread_client_config.current.object_id
  redirect_uris            = ["https://${var.cloudflare_team_domain}/cdn-cgi/access/callback"]
  msgraph_delegated_scopes = ["email", "offline_access", "openid", "User.Read"]
}

resource "cloudflare_zero_trust_access_identity_provider" "entra_id" {
  account_id = var.cloudflare_account_id
  name       = "Microsoft Entra ID - ${var.environment_name}"
  type       = "azureAD"

  config = {
    client_id     = module.cloudflare_sso_app.client_id
    client_secret = module.cloudflare_sso_app.client_secret
    directory_id  = data.azuread_client_config.current.tenant_id
  }
}

resource "cloudflare_zero_trust_access_policy" "cloudflare_sso" {
  account_id = var.cloudflare_account_id
  name       = "Allow Entra ID Users - ${var.environment_name}"
  decision   = "allow"

  include = [{
    email = {
      email = var.letsencrypt_email
    }
  }]
}
