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
