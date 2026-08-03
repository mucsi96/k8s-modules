output "bank_email_address" {
  description = "Address to register at the banks for card notification emails"
  value       = local.bank_email_address
  sensitive   = true
}
