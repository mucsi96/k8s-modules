variable "server_name" {
  description = "Name of the Hetzner server."
  type        = string
}

variable "location" {
  description = "Hetzner datacenter location, for example fsn1 or nbg1."
  type        = string
}

variable "server_type" {
  description = "Hetzner server type, for example cx22."
  type        = string
}

variable "image" {
  description = "OS image used for the server."
  type        = string
  default     = "ubuntu-24.04"
}

variable "ssh_username" {
  description = "Bootstrap SSH user to configure on the server."
  type        = string
  default     = "bootstrap"
}

variable "ssh_initial_port" {
  description = "Initial SSH port used by the bootstrap user."
  type        = number
  default     = 22
}
