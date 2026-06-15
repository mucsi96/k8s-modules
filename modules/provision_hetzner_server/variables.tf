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
  description = "Sudo user created via cloud-init. Authenticates with the generated SSH key and has NOPASSWD sudo."
  type        = string
  default     = "ubuntu"
}

variable "labels" {
  description = "Optional labels applied to the Hetzner Cloud server."
  type        = map(string)
  default     = {}
}

variable "cloudflare_ipv4_cidrs" {
  description = "Cloudflare edge IPv4 ranges allowed to reach port 443. All other public inbound is dropped by the host nftables firewall configured in cloud-init."
  type        = list(string)
}

variable "cloudflare_ipv6_cidrs" {
  description = "Cloudflare edge IPv6 ranges allowed to reach port 443. All other public inbound is dropped by the host nftables firewall configured in cloud-init."
  type        = list(string)
}

variable "twingate_network" {
  description = "Twingate network name (e.g. 'mynetwork' from mynetwork.twingate.com). Written to the host connector config as TWINGATE_NETWORK by cloud-init."
  type        = string
}

variable "twingate_access_token" {
  description = "Twingate host connector access token, baked into cloud-init user_data."
  type        = string
  sensitive   = true
}

variable "twingate_refresh_token" {
  description = "Twingate host connector refresh token, baked into cloud-init user_data."
  type        = string
  sensitive   = true
}

variable "ssh_ready_wait_for" {
  description = "Optional ordering barrier folded into the ssh_ready provisioner environment so the Twingate SSH resource exists before the keyscan poll runs over Twingate. Pass module.setup_twingate_access.ssh_resource_id."
  type        = string
  default     = null
}
