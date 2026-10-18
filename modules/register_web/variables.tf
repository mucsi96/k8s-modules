variable "owner" {
  description = "Owner object ID; the owner is also assigned access to the Web client."
  type        = string
}

variable "display_name" {
  description = "Display name of the confidential Web client."
  type        = string
}

variable "redirect_uris" {
  description = "Web callback URIs for the server-side authorization-code flow."
  type        = list(string)
  validation {
    condition     = length(var.redirect_uris) > 0
    error_message = "Supply at least one Web callback URI."
  }
}

variable "api_access" {
  description = "Optional API registration/scope to authorize. Header-authenticated and login-gated services can omit it."
  type = object({
    application_id = string
    client_id      = string
    scope_id       = string
  })
  default = null
}

variable "allowed_user_ids" {
  description = "Additional users assigned to the Web client; API role assignments remain separate."
  type        = set(string)
  default     = []
}
