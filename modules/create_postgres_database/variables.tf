variable "k8s_name" {
  description = "Kubernetes name"
  type        = string
}

variable "k8s_namespace" {
  description = "The name of the Kubernetes namespace to create"
  type        = string
}

variable "db_name" {
  description = "The name of the database to create"
  type        = string
}

variable "wait_for" {
  description = "Optional dependency to wait for before deploying."
  type        = string
  default     = null
}
