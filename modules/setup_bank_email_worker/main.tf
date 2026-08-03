locals {
  bank_email_address = "${var.email_local_part}@${var.dns_zone}"
}

# Workers scripts are account-level resources; resolve the account from the
# zone instead of requiring a separate account-id secret.
data "cloudflare_zone" "zone" {
  zone_id = var.cloudflare_zone_id
}

# Enables Email Routing on the zone (the email/routing/enable API), which
# provisions the required MX and SPF records at the apex. The proxied wildcard
# A record is unaffected — Email Routing only receives mail, it never serves
# HTTP. Not cloudflare_email_routing_dns: that resource manages *subdomain*
# routing and rejects the zone apex with a 422.
resource "cloudflare_email_routing_settings" "email_routing" {
  zone_id = var.cloudflare_zone_id
}

resource "cloudflare_workers_script" "bank_email_worker" {
  account_id         = data.cloudflare_zone.zone.account.id
  script_name        = "bank-email-notifications"
  content            = file("${path.module}/worker.js")
  main_module        = "worker.js"
  compatibility_date = "2025-01-01"

  bindings = [
    {
      name = "TARGET_URL"
      type = "plain_text"
      text = var.target_url
    },
    {
      name = "API_TOKEN"
      type = "secret_text"
      text = var.api_token
    }
  ]
}

resource "cloudflare_email_routing_rule" "bank_notifications" {
  zone_id  = var.cloudflare_zone_id
  name     = "Bank card notifications to expense tracker"
  enabled  = true
  priority = 0

  matchers = [{
    type  = "literal"
    field = "to"
    value = local.bank_email_address
  }]

  actions = [{
    type  = "worker"
    value = [cloudflare_workers_script.bank_email_worker.script_name]
  }]

  depends_on = [cloudflare_email_routing_settings.email_routing]
}
