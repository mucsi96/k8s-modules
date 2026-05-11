variable "display_name" {
  description = "Display name for the Entra application used by the GitHub Actions deploy pipeline to authenticate against the Kubernetes API server via kubelogin -l workloadidentity."
  type        = string
}

variable "owner" {
  description = "Object ID of the Entra application owner."
  type        = string
}

variable "github_subject" {
  description = "Federated credential subject claim (e.g. repo:owner/repo:ref:refs/heads/main, or repo:owner/repo:environment:production)."
  type        = string
}
