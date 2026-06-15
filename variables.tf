variable "hcloud_server_type" {
  description = "Hetzner Cloud server type for the cluster VPS (e.g. cpx32 = 4 vCPU shared AMD, 8 GB RAM, 160 GB NVMe). Required — no default to keep the operator from accidentally provisioning a size other than what the environment was capacity-planned for. Note: the old cx42 was retired by Hetzner; pick a current type (cpx32, cx33/cx43, cax21/cax31)."
  type        = string
}

variable "hcloud_location" {
  description = "Hetzner Cloud datacenter location (e.g. fsn1, nbg1, hel1, ash, hil)."
  type        = string
  default     = "nbg1"
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
