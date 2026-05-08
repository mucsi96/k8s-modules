variable "hcloud_server_type" {
  description = "Hetzner Cloud server type. CX42 = 8 vCPU shared Intel, 16 GB RAM, 160 GB SSD."
  type        = string
  default     = "cx42"
}

variable "hcloud_location" {
  description = "Hetzner Cloud datacenter location (e.g. fsn1, nbg1, hel1, ash, hil)."
  type        = string
  default     = "fsn1"
}

variable "hcloud_image" {
  description = "Hetzner Cloud OS image. setup_cluster requires Ubuntu 24.04+."
  type        = string
  default     = "ubuntu-24.04"
}

variable "hcloud_username" {
  description = "Sudo user created via cloud-init on the Hetzner Cloud server."
  type        = string
  default     = "ubuntu"
}

variable "local_python_interpreter" {
  description = "Absolute path to the Python interpreter on the Ansible controller (localhost) that has the azure.azcollection requirements installed."
  type        = string
  default     = "./.venv/bin/python"
}
