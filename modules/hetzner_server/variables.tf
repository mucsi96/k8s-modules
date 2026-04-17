variable "name" {
  description = "Name of the Hetzner Cloud server."
  type        = string
  default     = "k8s-node"
}

variable "server_type" {
  description = "Hetzner Cloud server type."
  type        = string
  default     = "cx42"
}

variable "location" {
  description = "Hetzner Cloud datacenter location."
  type        = string
  default     = "fsn1"
}

variable "image" {
  description = "OS image for the server."
  type        = string
  default     = "ubuntu-24.04"
}

variable "username" {
  description = "Non-root user to create on the server."
  type        = string
  default     = "k8s"
}
