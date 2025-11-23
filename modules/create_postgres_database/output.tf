output "username" {
  value      = random_string.db_username.result
  sensitive  = true
  depends_on = [helm_release.database]
}

output "password" {
  value      = random_password.db_password.result
  sensitive  = true
  depends_on = [helm_release.database]
}


output "jdbc_url" {
  value      = "jdbc:postgresql://${var.k8s_name}.${var.k8s_namespace}:5432/${var.db_name}"
  depends_on = [helm_release.database]
}
