output "email_address" {
  value     = "${var.email_local_part}@${var.dns_zone}"
  sensitive = true
}
