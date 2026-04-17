output "traefik_namespace" {
  value       = kubernetes_namespace_v1.traefik.metadata[0].name
  description = "Traefik namespace name"
}

output "traefik_ready" {
  value       = helm_release.traefik.status
  description = "Traefik Helm release status to ensure it's ready"
}

output "tunnel_id" {
  value       = cloudflare_zero_trust_tunnel_cloudflared.traefik_tunnel.id
  description = "Cloudflare tunnel ID for DNS CNAME targeting"
}
