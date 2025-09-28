variable "host" {
  description = "DNS name or IP address of the target Linux host accessible over SSH."
  type        = string
}

variable "initial_port" {
  description = "SSH port used to reach the target host."
  type        = number
  default     = 22
}

variable "username" {
  description = "Name of the user on the target host."
  type        = string
}

variable "initial_password" {
  description = "Initial password for the user on the target host."
  type        = string
  sensitive   = true
}
