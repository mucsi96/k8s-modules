locals {
  host = "${kubernetes_service_v1.redis.metadata[0].name}.${kubernetes_service_v1.redis.metadata[0].namespace}.svc.cluster.local"
}

output "host" {
  description = "In-cluster hostname of the Redis Service"
  value       = local.host
}

output "port" {
  description = "Port the Redis Service listens on"
  value       = local.port
}

output "connection_url" {
  description = "redis:// URL without the password; pair with the password output"
  value       = "redis://${local.host}:${local.port}"
}

output "password" {
  description = "Redis AUTH password"
  value       = random_password.password.result
  sensitive   = true
}

output "auth_secret_name" {
  description = "Name of the Kubernetes Secret holding the password under key 'redis-password'"
  value       = kubernetes_secret_v1.auth.metadata[0].name
}
