variable "server_name" {
  description = "Hostname assigned while installing Debian on the existing Netcup RS 1000 G12."
  type        = string

  validation {
    condition     = length(var.server_name) <= 200 && can(regex("^([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9])(\\.([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]))*$", var.server_name))
    error_message = "server_name must be a valid DNS hostname no longer than 200 characters."
  }
}

variable "netcup_server_id" {
  description = "SCP server ID of the already-contracted Netcup RS 1000 G12. The SCP API cannot order servers."
  type        = number
}

variable "netcup_user_id" {
  description = "SCP user ID used to manage account-level SSH keys and firewall policies."
  type        = number
}

variable "netcup_refresh_token" {
  description = "Long-lived SCP OAuth2 refresh token loaded and persisted by the caller's secret store."
  type        = string
  sensitive   = true

  validation {
    condition     = length(trimspace(var.netcup_refresh_token)) > 0
    error_message = "netcup_refresh_token must be non-empty."
  }
}

variable "netcup_api_url" {
  description = "Netcup Server Control Panel REST API base URL."
  type        = string
  default     = "https://www.servercontrolpanel.de/scp-core"
}

variable "netcup_image_flavour_id" {
  description = "Server-specific Debian 13 image flavour ID returned by GET /api/v1/servers/{id}/imageflavours."
  type        = number
}

variable "netcup_disk_name" {
  description = "Target disk returned by GET /api/v1/servers/{id}/disks, for example scsi0. Its contents are erased."
  type        = string
}

variable "reinstall_generation" {
  description = "Explicit non-empty approval token for the destructive Debian reinstall. Change it only to intentionally reinstall and erase the selected disk again."
  type        = string
  sensitive   = true

  validation {
    condition     = length(trimspace(var.reinstall_generation)) > 0
    error_message = "reinstall_generation must be non-empty to approve the destructive Netcup image installation."
  }
}

variable "username" {
  description = "Passwordless sudo user created by the Netcup image installer and hardened by its custom script."
  type        = string
  default     = "debian"

  validation {
    condition     = can(regex("^[a-z][a-z0-9_]{0,30}$", var.username))
    error_message = "username must match Netcup's additionalUserUsername format."
  }
}

variable "https_source_ips" {
  description = "Cloudflare edge CIDRs allowed to reach public TCP port 443. Any ingress rule makes Netcup's implicit ingress action DROP."
  type        = list(string)

  validation {
    condition     = length(var.https_source_ips) > 0
    error_message = "At least one Cloudflare edge CIDR is required."
  }
}

variable "netcup_interface_mac" {
  description = "Optional public interface MAC. By default the first non-VLAN interface reported by the SCP API is used."
  type        = string
  default     = null
}

variable "twingate_network" {
  description = "Twingate network name, for example 'mynetwork' from mynetwork.twingate.com."
  type        = string
}

variable "twingate_access_token" {
  description = "Twingate host connector access token embedded in the Netcup image installation script."
  type        = string
  sensitive   = true
}

variable "twingate_refresh_token" {
  description = "Twingate host connector refresh token embedded in the Netcup image installation script."
  type        = string
  sensitive   = true
}

variable "ssh_ready_wait_for" {
  description = "Optional ordering barrier that keeps Twingate SSH and Kubernetes API resources alive through cluster teardown."
  type        = string
  default     = null
}
