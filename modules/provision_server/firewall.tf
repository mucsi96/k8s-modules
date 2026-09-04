# Once any inbound rule exists, hcloud drops all other inbound traffic;
# outbound stays unrestricted (Twingate connector, apt, Key Vault, ACME all
# connect outward). The ONLY public inbound rule is port 443 from the Cloudflare
# edge, so the zone rulesets (rate limiting, ASN restriction, bot blocking)
# cannot be bypassed by connecting to the server IP directly. There is
# deliberately no port 80 rule: the edge redirects HTTP to HTTPS before reaching
# the origin.
#
# SSH (the randomized port), the Kubernetes API (16443), and ICMP are NOT exposed
# publicly — they are reachable only through Twingate. The host connector
# (installed by cloud-init, see setup_twingate_connector) dials out to Twingate,
# and connector traffic to the node's own public IP is delivered locally without
# crossing this firewall, so kubeconfig (https://publicIP:16443) and SSH keep
# working for operators/CI on the Twingate network. random_integer.ssh_port is
# kept (defense-in-depth: it still drives sshd and cloud-init).
resource "hcloud_firewall" "this" {
  name = var.server_name

  rule {
    description = "HTTPS from the Cloudflare edge only"
    direction   = "in"
    protocol    = "tcp"
    port        = "443"
    source_ips  = var.https_source_ips
  }
}

resource "hcloud_firewall_attachment" "this" {
  firewall_id = hcloud_firewall.this.id
  server_ids  = [hcloud_server.this.id]
}
