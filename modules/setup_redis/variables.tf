variable "k8s_name" {
  description = "Helm release name for Redis. Used as the name of the Deployment, Service, Secret, and PVC the chart creates. Mirrors the k8s_name convention used by create_postgres_database."
  type        = string
}

variable "k8s_namespace" {
  description = "Kubernetes namespace where Redis is deployed (typically a shared 'redis' namespace, the same way the central Postgres lives in 'db')"
  type        = string
}
