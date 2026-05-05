variable "k8s_name" {
  description = "Name of the Redis Deployment, Service and the prefix for its auth Secret. Mirrors the k8s_name convention used by create_postgres_database."
  type        = string
}

variable "k8s_namespace" {
  description = "Kubernetes namespace where Redis is deployed (typically a shared 'redis' namespace, the same way the central Postgres lives in 'db')"
  type        = string
}

variable "image" {
  description = "Redis container image"
  type        = string
  default     = "redis:7-alpine"
}
