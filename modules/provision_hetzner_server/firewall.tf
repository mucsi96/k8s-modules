# Once any inbound rule exists, hcloud drops all other inbound traffic;
# outbound stays unrestricted (Twingate connector, apt, Key Vault, ACME all
# connect outward). Port 443 is reachable from the Cloudflare edge only, so
# the zone rulesets (rate limiting, ASN restriction, bot blocking) cannot be
# bypassed by connecting to the server IP directly. There is deliberately no
# port 80 rule: the edge redirects HTTP to HTTPS before reaching the origin.
resource "hcloud_firewall" "this" {
  name = var.server_name

  rule {
    description = "HTTPS from the Cloudflare edge only"
    direction   = "in"
    protocol    = "tcp"
    port        = "443"
    source_ips  = var.https_source_ips
  }

  rule {
    description = "SSH on the randomized port"
    direction   = "in"
    protocol    = "tcp"
    port        = tostring(random_integer.ssh_port.result)
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  rule {
    description = "Kubernetes API (MicroK8s, client certificate auth)"
    direction   = "in"
    protocol    = "tcp"
    port        = "16443"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  rule {
    description = "ICMP for diagnostics"
    direction   = "in"
    protocol    = "icmp"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }
}

resource "hcloud_firewall_attachment" "this" {
  firewall_id = hcloud_firewall.this.id
  server_ids  = [hcloud_server.this.id]
}
