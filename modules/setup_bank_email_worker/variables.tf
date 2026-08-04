variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID of the domain receiving the bank notification emails"
  type        = string
}

variable "dns_zone" {
  description = "Domain of the zone; the bank notification address is <email_local_part>@<dns_zone>"
  type        = string
  sensitive   = true
}

variable "email_local_part" {
  description = "Local part of the email address the banks send card notifications to"
  type        = string
  default     = "bank"
}

variable "target_url" {
  description = "Expense tracker REST endpoint the worker POSTs received emails to"
  type        = string
}

variable "allowed_senders" {
  description = "Sender addresses whose emails the worker forwards; mail from anyone else is dropped"
  type        = list(string)
  default     = ["noreply-alerting@ubs.com"]
}

variable "subject_prefix" {
  description = "Only emails whose subject starts with this prefix (case-insensitive) are forwarded"
  type        = string
  default     = "UBS Digital Banking: Card debit"
}

variable "api_token" {
  description = "Bearer token the worker sends in the Authorization header; the expense tracker API validates it against its bank-notification-token Key Vault secret"
  type        = string
  sensitive   = true
}
