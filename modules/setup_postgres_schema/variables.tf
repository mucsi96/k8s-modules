variable "database" {
  description = "PostgreSQL endpoint, Helm deployment, storage instance ID, and operator SSH connection used for apply-time provisioning."
  type = object({
    host        = string
    port        = number
    name        = string
    jdbc_url    = string
    namespace   = string
    deployment  = string
    instance_id = string
    ssh = object({
      host     = string
      port     = number
      username = string
    })
  })
}

variable "schema" {
  description = "Schema and same-named login role owned by the calling application module."
  type        = string

  validation {
    condition = (
      can(regex("^[a-z_][a-z0-9_]{0,62}$", var.schema)) &&
      substr(var.schema, 0, 3) != "pg_" &&
      !contains(["information_schema", "public"], var.schema)
    )
    error_message = "Schema must be a non-system, unquoted PostgreSQL identifier of at most 63 characters."
  }
}
