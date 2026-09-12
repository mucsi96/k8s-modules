data "cloudflare_zone" "zone" {
  zone_id = var.cloudflare_zone_id
}

# Zone-wide Email Routing/MX records are owned by setup_bank_email_worker.
# Reuse its raw-MIME forwarding and sender-authentication implementation.
resource "cloudflare_workers_script" "recipe_email_worker" {
  account_id         = data.cloudflare_zone.zone.account.id
  script_name        = "recipe-email-import"
  content            = file("${path.module}/../setup_bank_email_worker/worker.js")
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

resource "cloudflare_email_routing_rule" "recipes" {
  zone_id  = var.cloudflare_zone_id
  name     = "Recipes to cooking app"
  enabled  = true
  priority = 0

  matchers = [{
    type  = "literal"
    field = "to"
    value = "${var.email_local_part}@${var.dns_zone}"
  }]

  actions = [{
    type  = "worker"
    value = [cloudflare_workers_script.recipe_email_worker.script_name]
  }]
}
