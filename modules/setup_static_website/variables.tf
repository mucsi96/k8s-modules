variable "name" {
  type = string
  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.name))
    error_message = "Storage account names must contain 3–24 lowercase letters or digits."
  }
}

variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "deploy_principal_id" { type = string }

variable "app_origin" {
  description = "HTTPS application origin allowed to fetch public static assets with CORS."
  type        = string
  validation {
    condition     = can(regex("^https://[a-z0-9][a-z0-9.-]*[a-z0-9]$", var.app_origin))
    error_message = "app_origin must be an HTTPS origin without a path or trailing slash."
  }
}
