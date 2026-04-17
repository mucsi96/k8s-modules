output "cloudflare_tunnel_id" {
  description = "Cloudflare tunnel ID for this environment. Point the wildcard CNAME record at <id>.cfargotunnel.com to route traffic here."
  value       = module.setup_ingress_controller.cloudflare_tunnel_id
}

output "cloudflare_tunnel_cname_target" {
  description = "Value to set as the content of the wildcard CNAME record in Cloudflare to direct traffic to this environment."
  value       = module.setup_ingress_controller.cloudflare_tunnel_cname_target
}
