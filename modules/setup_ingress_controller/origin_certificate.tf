# Cloudflare Origin CA certificate served by Traefik. Only the Cloudflare
# edge trusts this CA, which is fine: with the proxied DNS record and the
# hcloud firewall, the edge is the only client that ever reaches port 443.
# 5475 days (15 years) is the maximum validity, so no renewal automation is
# needed.

resource "tls_private_key" "origin" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "origin" {
  private_key_pem = tls_private_key.origin.private_key_pem

  subject {
    common_name = var.dns_zone
  }
}

# hostnames is in ignore_changes below, so a dns_zone change would no longer
# reissue the certificate on its own; this sentinel routes it through
# replace_triggered_by instead.
resource "terraform_data" "origin_cert_hostnames" {
  input = var.dns_zone
}

resource "cloudflare_origin_ca_certificate" "origin" {
  csr                = tls_cert_request.origin.cert_request_pem
  hostnames          = [var.dns_zone, "*.${var.dns_zone}"]
  request_type       = "origin-rsa"
  requested_validity = 5475

  # Provider v5 force-replaces this resource on every apply
  # (cloudflare/terraform-provider-cloudflare#5392): the Origin CA API does
  # not echo csr/requested_validity back on reads and returns hostnames in
  # its own order, so refresh always produces a phantom diff. Every input
  # that genuinely requires reissuing is covered by replace_triggered_by:
  # a rotated private key and a changed dns_zone.
  lifecycle {
    ignore_changes = [csr, requested_validity, hostnames]
    replace_triggered_by = [
      tls_private_key.origin,
      terraform_data.origin_cert_hostnames,
    ]
  }
}

# TLS secret referenced by the Gateway's HTTPS listener (gateway.tf). The
# Gateway listener terminates TLS with this cert; there is no Traefik TLSStore
# anymore (that was a kubernetesCRD resource, and that provider is disabled).
resource "kubernetes_secret_v1" "origin_tls" {
  metadata {
    name      = "cloudflare-origin-tls"
    namespace = kubernetes_namespace_v1.traefik.metadata[0].name
  }

  type = "kubernetes.io/tls"

  data = {
    "tls.crt" = cloudflare_origin_ca_certificate.origin.certificate
    "tls.key" = tls_private_key.origin.private_key_pem
  }
}
