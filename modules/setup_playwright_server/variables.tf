variable "k8s_namespace" {
  description = "The Kubernetes namespace to deploy into"
  type        = string
}

variable "playwright_version" {
  description = "The Playwright server Docker image version"
  type        = string
}
