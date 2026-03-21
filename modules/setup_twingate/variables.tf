variable "twingate_network" {
  description = "The Twingate network name (e.g. 'mynetwork' from mynetwork.twingate.com)"
  type        = string
}

variable "twingate_api_token" {
  description = "Twingate API token with Read, Write & Provision permissions"
  type        = string
  sensitive   = true
}

variable "environment_name" {
  description = "The name of the environment"
  type        = string
}

variable "k8s_host" {
  description = "The Kubernetes API server endpoint (used as Twingate resource address)"
  type        = string
  sensitive   = true
}
