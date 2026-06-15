variable "environment_name" {
  description = "The name of the environment"
  type        = string
}

variable "operator_email" {
  description = "Email of the Twingate user granted operator (SSH + K8s API) access. Must resolve to exactly one Twingate user."
  type        = string
  sensitive   = true
}

variable "remote_network_id" {
  description = "Twingate remote network ID from setup_twingate_connector."
  type        = string
}

variable "k8s_host" {
  description = "Address (public IPv4) of the Kubernetes API server, used as the Twingate resource address."
  type        = string
  sensitive   = true
}

variable "ssh_address" {
  description = "Address (public IPv4) of the host's SSH endpoint, used as the Twingate resource address."
  type        = string
}

variable "ssh_port" {
  description = "Randomized SSH port the host listens on."
  type        = number
}
