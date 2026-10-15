variable "owner" {
  description = "The owner of the resources"
  type        = string
}

variable "display_name" {
  description = "The display name of the SPA"
  type        = string
}

variable "redirect_uris" {
  description = "The redirect URIs for the SPA"
  type        = list(string)
}

variable "api_client_id" {
  description = "The client ID of the API"
  type        = string
}

variable "api_scope_id" {
  description = "The scope ID of the API"
  type        = string
}

variable "api_id" {
  description = "The ID of the API"
  type        = string
}

variable "web_redirect_uris" {
  description = "Non-empty converts the existing client in place to a confidential Web client; removes its SPA redirect type."
  type        = list(string)
  default     = []
}

variable "allowed_user_ids" {
  description = "Additional users assigned to the confidential Web client. The owner is always assigned. API role assignments remain separate."
  type        = set(string)
  default     = []
}

variable "retain_spa_redirects" {
  description = "Temporary rollout bridge: retain the old SPA redirects while adding the confidential Web callback. Remove after deploying the cookie-auth client."
  type        = bool
  default     = false
}
