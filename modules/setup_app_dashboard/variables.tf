variable "environment_name" { type = string }
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
variable "kubeconfig_secret_id" {
  description = "Versionless resource ID of the platform k8s-oidc-config Key Vault secret."
  type        = string
}
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
