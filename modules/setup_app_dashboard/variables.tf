variable "environment_name" { type = string }
variable "hostname" { type = string }
variable "image" {
  description = "Published dashboard image, pinned to an immutable sha tag or digest."
  type        = string
  validation {
    condition     = can(regex("(:sha-[a-f0-9]{40}|@sha256:[a-f0-9]{64})$", var.image))
    error_message = "Use an immutable :sha-<40 character commit> tag or @sha256 digest."
  }
}
variable "apps" {
  description = "Application descriptors exported by setup_*_app modules."
  type = list(object({
    name       = string
    namespace  = string
    repository = string
    url        = string
  }))
}
variable "github_token" {
  type      = string
  sensitive = true
}
variable "owner" { type = string }
variable "tenant_id" { type = string }
variable "valid_email" {
  type      = string
  sensitive = true
}
variable "oauth2_proxy_chart_version" { type = string }
variable "oauth2_proxy_image_version" { type = string }
variable "session_redis" {
  type      = object({ connection_url = string, password = string })
  sensitive = true
}
variable "gateway_parent_ref" {
  type = object({ name = string, namespace = string, section_name = string })
}
variable "wait_for" { type = string }
