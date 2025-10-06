resource "kubernetes_namespace" "cloudflare_namespace" {
  metadata {
    name = "cloudflare"
  }
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "traefik_tunnel" {
  account_id    = var.cloudflare_account_id
  name          = "${var.resource_group_name}-traefik-tunnel"
  config_src    = "local"
  tunnel_secret = base64sha256("${var.resource_group_name}-${random_id.tunnel_secret.hex}")
}

resource "random_id" "tunnel_secret" {
  byte_length = 32
}

# Deploy cloudflared using the official Cloudflare Helm chart
resource "helm_release" "cloudflared" {
  name       = "cloudflared"
  repository = "https://cloudflare.github.io/helm-charts"
  chart      = "cloudflared"
  namespace  = kubernetes_namespace.cloudflare_namespace.metadata[0].name
  version    = "0.1.0" # Check for the latest version

  values = [yamlencode({
    tunnelId  = cloudflare_zero_trust_tunnel_cloudflared.traefik_tunnel.id
    accountId = var.cloudflare_account_id
    secret    = cloudflare_zero_trust_tunnel_cloudflared.traefik_tunnel.tunnel_secret
    ingress = [{
      hostname = "*.${var.resource_group_name}.${var.dns_zone}"
      service  = "http://traefik.${kubernetes_namespace.k8s_namespace.metadata[0].name}.svc.cluster.local:80"
    }]
  })]

  depends_on = [
    cloudflare_zero_trust_tunnel_cloudflared.traefik_tunnel
  ]
}

resource "cloudflare_dns_record" "cname_record" {
  zone_id = var.cloudflare_zone_id
  name    = "*"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.traefik_tunnel.id}.cfargotunnel.com"
  type    = "CNAME"
  ttl     = 1
  proxied = true

  depends_on = [
    helm_release.cloudflared
  ]
}
