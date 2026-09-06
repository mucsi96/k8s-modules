variable "k8s_name" {
  description = "Kubernetes name"
  type        = string
}

variable "k8s_namespace" {
  description = "The name of the Kubernetes namespace to create"
  type        = string
}

variable "db_name" {
  description = "The name of the database to create"
  type        = string
}

variable "application_schemas" {
  description = "Schema names to provision. Each schema gets a same-named login role that owns it."
  type        = set(string)
  default     = []

  validation {
    condition = alltrue([
      for schema in var.application_schemas :
      can(regex("^[a-z_][a-z0-9_]{0,62}$", schema)) &&
      substr(schema, 0, 3) != "pg_" &&
      !contains(["information_schema", "public"], schema)
    ])
    error_message = "Application schema names must be non-system, unquoted PostgreSQL identifiers of at most 63 characters."
  }
}

variable "admin_password_active_slot" {
  description = "Active bootstrap password slot. To rotate, regenerate the inactive slot and switch this value in the same apply."
  type        = string
  default     = "green"

  validation {
    condition     = contains(["blue", "green"], var.admin_password_active_slot)
    error_message = "Admin password active slot must be either blue or green."
  }
}

variable "admin_password_blue_generation" {
  description = "Blue bootstrap password generation. Leave null for the initial migration, then change it whenever switching to blue."
  type        = string
  default     = null
  nullable    = true
}

variable "admin_password_green_generation" {
  description = "Green bootstrap password generation. Change it whenever switching to green."
  type        = string
  default     = "initial"
}

variable "role_provisioning_generation" {
  description = "Change this value to rerun role and schema provisioning after an out-of-band database reinitialization."
  type        = string
  default     = "initial"
}

variable "wait_for" {
  description = "Optional dependency to wait for before deploying. The postgres-db chart ships a ServiceMonitor, so this must gate on the Prometheus Operator CRDs being installed."
  type        = string
  default     = null
}
