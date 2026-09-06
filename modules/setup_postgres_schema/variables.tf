variable "resource_group_name" {
  description = "Resource group for the dedicated schema-provisioning identity."
  type        = string
}

variable "azure_location" {
  description = "Azure location for the schema-provisioning identity."
  type        = string
}

variable "k8s_oidc_issuer_url" {
  description = "Published Kubernetes workload identity issuer. Must also order after the workload identity webhook is ready."
  type        = string
}

variable "password_secret" {
  description = "Versioned Key Vault password URL and versionless ARM secret ID for read-only access. Publish the password output before passing these IDs back into this module."
  type = object({
    id                      = string
    resource_versionless_id = string
  })
}

variable "database" {
  description = "PostgreSQL endpoint and namespace-local administrator Secret used to provision the schema."
  type = object({
    host              = string
    port              = number
    name              = string
    jdbc_url          = string
    namespace         = string
    admin_secret_name = string
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
