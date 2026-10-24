variable "environment_name" { type = string }
variable "client_storage_account_name" {
  description = "Globally unique Azure Storage account name for public client documents and assets."
  type        = string
}
variable "hostname" { type = string }
variable "github_repository_owner" {
  type    = string
  default = "mucsi96"
}
variable "github_repository" {
  type    = string
  default = "observatory-app"
}
variable "azure_subscription_id" { type = string }
variable "twingate_service_key" {
  type      = string
  sensitive = true
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
variable "azure_location" { type = string }
variable "k8s_oidc_config" {
  type      = string
  sensitive = true
}
variable "k8s_oidc_issuer_url" { type = string }
variable "client_log_url" { type = string }
variable "ingress_controller_namespace" { type = string }
variable "forward_auth" {
  type = object({
    trusted_proxy_cidrs = list(string)
    session_redis       = object({ connection_url = string, password = string })
    gateway_parent_ref  = object({ name = string, namespace = string, section_name = string })
  })
  sensitive = true
}
variable "wait_for" { type = string }
