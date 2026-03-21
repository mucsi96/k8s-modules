output "service_key" {
  description = "Twingate service key for GitHub Actions. Store as TWINGATE_SERVICE_KEY secret in GitHub."
  value       = twingate_service_account_key.github_actions.token
  sensitive   = true
}
