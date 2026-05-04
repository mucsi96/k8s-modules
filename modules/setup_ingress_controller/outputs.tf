output "traefik_namespace" {
  value       = kubernetes_namespace_v1.traefik.metadata[0].name
  description = "Traefik namespace name"
}

output "traefik_ready" {
  value       = helm_release.traefik.status
  description = "Traefik Helm release status to ensure it's ready"
}

output "cloudflare_access_policy_id" {
  value       = cloudflare_zero_trust_access_policy.cloudflare_sso.id
  description = "Cloudflare Zero Trust Access policy id reused by other apps that need the same SSO protection."
}

output "cloudflare_identity_provider_id" {
  value       = cloudflare_zero_trust_access_identity_provider.entra_id.id
  description = "Cloudflare Zero Trust identity provider id reused by other apps."
}
