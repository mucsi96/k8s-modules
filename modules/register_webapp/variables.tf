variable "owner" {
  description = "The owner of the resources"
  type        = string
}

variable "display_name" {
  description = "The display name of the webapp"
  type        = string
}

variable "redirect_uris" {
  description = "The redirect URIs for the webapp (e.g. the OAuth2 callback URL)"
  type        = list(string)
}
