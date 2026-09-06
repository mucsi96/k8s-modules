output "password" {
  description = "Password to publish to Key Vault before initialization; deliberately not gated on the Job."
  value       = random_password.password.result
  sensitive   = true
}

output "credentials" {
  description = "Credentials for the same-named login role that owns the schema."
  value = {
    username = var.schema
    password = random_password.password.result
  }
  sensitive  = true
  depends_on = [kubernetes_job_v1.init]
}

output "jdbc_url" {
  value = var.database.jdbc_url
}
