output "username" {
  value     = random_string.db_username.result
  sensitive = true
}

output "password" {
  value     = random_password.db_password.result
  sensitive = true
}


output "jdbc_url" {
  value = "jdbc:postgresql://${var.k8s_name}.${var.k8s_namespace}:5432/${var.db_name}"
}

output "host" {
  description = "In-cluster DNS name of the database Service"
  value       = "${var.k8s_name}.${var.k8s_namespace}"
}

output "port" {
  description = "TCP port the database Service listens on"
  value       = 5432
}

output "name" {
  description = "Name of the database created inside the Postgres instance"
  value       = var.db_name
}
