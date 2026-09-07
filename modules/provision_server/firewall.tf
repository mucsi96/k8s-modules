locals {
  firewall_policy_name = "${var.server_name}-cloudflare-https"
  firewall_policy_body = jsonencode({
    name        = local.firewall_policy_name
    description = "Terraform managed: public HTTPS from Cloudflare and NTP replies"
    rules = [
      {
        description      = "HTTPS from the Cloudflare edge only"
        direction        = "INGRESS"
        protocol         = "TCP"
        action           = "ACCEPT"
        sources          = var.https_source_ips
        destinationPorts = "443"
      },
      {
        description = "NTP replies to the host"
        direction   = "INGRESS"
        protocol    = "UDP"
        action      = "ACCEPT"
        sources = [
          "162.159.200.1/32",
          "162.159.200.123/32",
          "2606:4700:f1::1/128",
          "2606:4700:f1::123/128",
        ]
        sourcePorts = "123"
      },
    ]
  })
}

# Netcup changes the implicit ingress action to DROP as soon as this policy has
# an ingress rule. Its UDP handling is stateless, so NTP replies need an
# explicit ingress rule. Netcup's copied mandatory policies are preserved for
# DNS and installation traffic. No egress rule is defined, so implicit egress
# remains ACCEPT. SSH and the k3s API are reachable only through Twingate.
data "http" "firewall_policies" {
  url             = "${trimsuffix(var.netcup_api_url, "/")}/api/v1/users/${var.netcup_user_id}/firewall-policies?limit=500"
  request_headers = local.netcup_headers
}

data "http" "interface_firewall" {
  url             = "${trimsuffix(var.netcup_api_url, "/")}/api/v1/servers/${var.netcup_server_id}/interfaces/${local.interface_mac}/firewall"
  request_headers = local.netcup_headers
}

locals {
  observed_firewall_policies = [
    for policy in jsondecode(data.http.firewall_policies.response_body) : policy
    if policy.name == local.firewall_policy_name
  ]
  observed_firewall = jsondecode(data.http.interface_firewall.response_body)
  observed_firewall_state = {
    policy     = try(local.observed_firewall_policies[0], null)
    active     = try(local.observed_firewall.active, false)
    policy_ids = sort([for policy in try(local.observed_firewall.userPolicies, []) : tostring(policy.id)])
  }
}

resource "terraform_data" "netcup_firewall" {
  triggers_replace = {
    server_id             = tostring(var.netcup_server_id)
    interface_mac         = local.interface_mac
    policy_sha256         = sha256(local.firewall_policy_body)
    observed_state_sha256 = sha256(jsonencode(local.observed_firewall_state))
  }

  lifecycle {
    precondition {
      condition     = local.interface_mac != ""
      error_message = "No public Netcup server interface was found; set netcup_interface_mac explicitly."
    }
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      NETCUP_API_URL          = trimsuffix(var.netcup_api_url, "/")
      NETCUP_CLIENT_ID        = local.netcup_client_id
      NETCUP_TOKEN_URL        = local.netcup_token_url
      NETCUP_TOKEN            = local.netcup_access_token
      NETCUP_TOKEN_REFRESH_AT = data.external.netcup_token.result.refresh_at
      NETCUP_REFRESH_TOKEN    = local.netcup_refresh_token
      NETCUP_USER_ID          = tostring(var.netcup_user_id)
      SERVER_ID               = tostring(var.netcup_server_id)
      INTERFACE_MAC           = local.interface_mac
      FIREWALL_POLICY_NAME    = local.firewall_policy_name
      FIREWALL_POLICY_BODY    = local.firewall_policy_body
    }
    command = "bash \"${path.module}/netcup_api.sh\" firewall"
  }
}
