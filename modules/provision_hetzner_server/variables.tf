variable "server_name" {
  description = "Name of the Hetzner Cloud server."
  type        = string
}

variable "server_type" {
  description = "Hetzner Cloud server type. CX42 = 8 vCPU shared Intel, 16 GB RAM, 160 GB SSD (~€16/month)."
  type        = string
  default     = "cx42"
}

variable "location" {
  description = "Hetzner Cloud datacenter location (e.g. fsn1, nbg1, hel1, ash, hil)."
  type        = string
  default     = "fsn1"
}

variable "image" {
  description = "Operating system image. setup_cluster requires Ubuntu 24.04+."
  type        = string
  default     = "ubuntu-24.04"
}

variable "username" {
  description = "Initial sudo user created via cloud-init."
  type        = string
  default     = "ubuntu"
}

variable "labels" {
  description = "Optional labels applied to the Hetzner Cloud server."
  type        = map(string)
  default     = {}
}
