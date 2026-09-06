variable "environment_name" {
  description = "The name of the environment"
  type        = string
}

variable "azure_location" {
  description = "The Azure location to deploy resources"
  type        = string
}

variable "openai_api_key" {
  description = "OpenAI API key used by the application."
  type        = string
  sensitive   = true
}

variable "k8s_oidc_issuer_url" {
  description = "The OIDC issuer URL for the Kubernetes cluster"
  type        = string
}

variable "owner" {
  description = "The owner of the resources"
  type        = string
}

variable "hostname" {
  description = "The DNS zone hostname"
  type        = string
}

variable "tenant_id" {
  description = "The Azure AD tenant ID"
  type        = string
}

variable "azure_subscription_id" {
  description = "The Azure subscription ID the app deploys into."
  type        = string
}

variable "database" {
  description = "PostgreSQL instance in which this module owns the library role and schema."
  type = object({
    host        = string
    port        = number
    name        = string
    jdbc_url    = string
    namespace   = string
    deployment  = string
    instance_id = string
    ssh = object({
      host     = string
      port     = number
      username = string
    })
  })
}

variable "twingate_service_key" {
  description = "Twingate service key for this app's GitHub Actions pipeline."
  type        = string
  sensitive   = true
}

variable "k8s_oidc_config" {
  description = "Rendered kubelogin kubeconfig from setup_cluster. Forwarded to setup_app_base as the app's k8s-config Key Vault secret."
  type        = string
  sensitive   = true
}

variable "client_log_url" {
  description = "URL the app's SPA POSTs client-side telemetry to. Forwarded to setup_app_base, which stores it in this app's Key Vault as `client-log-url`."
  type        = string
}
