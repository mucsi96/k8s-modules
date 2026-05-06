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

variable "pv_name" {
  description = "Name of the cluster-scoped PersistentVolume backing this database. Defaults to k8s_name; override only when an existing PV must be preserved."
  type        = string
  default     = null
}

variable "host_path" {
  description = "Host filesystem path used by the database PersistentVolume. Defaults to /data/<k8s_name>; override only when an existing PV must be preserved."
  type        = string
  default     = null
}

