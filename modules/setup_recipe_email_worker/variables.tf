variable "cloudflare_zone_id" {
  description = "Cloudflare zone with Email Routing already enabled"
  type        = string
}

variable "dns_zone" {
  type      = string
  sensitive = true
}

variable "email_local_part" {
  description = "Recipe import email address local part"
  type        = string
  default     = "recipes"
}

variable "target_url" {
  description = "Cooking API endpoint receiving raw MIME email as JSON"
  type        = string
}

variable "api_token" {
  description = "Shared recipe-email-token from the cooking app Key Vault"
  type        = string
  sensitive   = true
}
