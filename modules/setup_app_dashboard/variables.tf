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
variable "client_log_url" {
  description = "Faro collector endpoint exposed in the public client environment."
  type        = string
}
variable "k8s_oidc_issuer_url" {
  description = "Cluster OIDC issuer for the shared API registration's workload identity."
  type        = string
}
variable "ingress_controller_namespace" {
  description = "Namespace of the Traefik pods allowed to reach Observatory."
  type        = string
}
variable "wait_for" { type = string }
