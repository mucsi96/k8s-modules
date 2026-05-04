variable "display_name" {
  description = "The display name of the Entra ID application"
  type        = string
}

variable "owner" {
  description = "The owner object ID for the Entra ID application"
  type        = string
}

variable "redirect_uris" {
  description = "The web redirect URIs for the application"
  type        = list(string)
}

variable "id_token_issuance_enabled" {
  description = "Whether to enable id_token implicit grant flow"
  type        = bool
  default     = true
}

variable "access_token_issuance_enabled" {
  description = "Whether to enable access_token implicit grant flow"
  type        = bool
  default     = false
}

variable "msgraph_delegated_scopes" {
  description = "Microsoft Graph delegated scopes to grant to the application"
  type        = list(string)
  default     = ["openid", "User.Read"]
}
