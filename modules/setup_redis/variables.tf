variable "name" {
  description = "Resource name prefix used for the Redis Deployment, Service and Secret"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace where Redis is deployed"
  type        = string
}

variable "image" {
  description = "Redis container image"
  type        = string
  default     = "redis:7-alpine"
}
