resource "tls_private_key" "private_key" {
  algorithm = "RSA"
}

resource "acme_registration" "reg" {
  account_key_pem = tls_private_key.private_key.private_key_pem
  email_address   = var.letsencrypt_email
}

resource "acme_certificate" "certificate" {
  account_key_pem           = acme_registration.reg.account_key_pem
  common_name               = "${var.resource_group_name}.${var.dns_zone}"
  subject_alternative_names = ["*.${var.resource_group_name}.${var.dns_zone}"]

  dns_challenge {
    provider = "azuredns"

    config = {
      AZURE_SUBSCRIPTION_ID = var.subscription_id
      AZURE_RESOURCE_GROUP  = var.resource_group_name
    }
  }
}
