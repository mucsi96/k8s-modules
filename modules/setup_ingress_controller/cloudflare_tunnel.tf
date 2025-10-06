resource "kubernetes_namespace" "cloudflare" {
  metadata {
    name = "cloudflare"
  }
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "traefik_tunnel" {
  account_id = var.cloudflare_account_id
  name       = "${var.resource_group_name} tunnel"
  config_src = "cloudflare"
}

data "cloudflare_zero_trust_tunnel_cloudflared_token" "traefik_tunnel_token" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.traefik_tunnel.id
}

resource "cloudflare_dns_record" "cname_record" {
  zone_id = var.cloudflare_zone_id
  name    = "*"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.traefik_tunnel.id}.cfargotunnel.com"
  type    = "CNAME"
  ttl     = 1
  proxied = true
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "traefik_tunnel_config" {
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.traefik_tunnel.id
  account_id = var.cloudflare_account_id
  source     = "cloudflare"

  config = {
    ingress = [
      {
        hostname = "traefik.${var.dns_zone}"
        service  = "http://traefik.${kubernetes_namespace.traefik.metadata[0].name}.svc.cluster.local:8080"
      },
      {
        hostname = "*.${var.dns_zone}"
        service  = "http://traefik.${kubernetes_namespace.traefik.metadata[0].name}.svc.cluster.local:80"
      },
      {
        service = "http_status:404"
      }
    ]
  }
}

resource "helm_release" "cloudflared" {
  name       = "cloudflared"
  repository = "https://cloudflare.github.io/helm-charts"
  chart      = "cloudflare-tunnel-remote"
  namespace  = kubernetes_namespace.cloudflare.metadata[0].name
  version    = "0.1.2" # https://github.com/cloudflare/helm-charts/releases

  values = [yamlencode({
    #Values: https://github.com/cloudflare/helm-charts/blob/main/charts/cloudflare-tunnel-remote/values.yaml
    cloudflare = {
      tunnel_token = data.cloudflare_zero_trust_tunnel_cloudflared_token.traefik_tunnel_token.token
    }
  })]
}
