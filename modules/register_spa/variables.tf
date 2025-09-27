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

variable "api_scope_ids" {
  description = "The scope IDs of the API"
  type        = list(string)
}

variable "api_id" {
  description = "The ID of the API"
  type        = string
}
