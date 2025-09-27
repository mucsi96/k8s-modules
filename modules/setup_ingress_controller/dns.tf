resource "azurerm_dns_zone" "dns_zone" {
  resource_group_name = var.resource_group_name
  name                = var.dns_zone
}

resource "azurerm_dns_a_record" "dns_a_record" {
  resource_group_name = var.resource_group_name
  zone_name           = azurerm_dns_zone.dns_zone.name
  name                = var.resource_group_name
  ttl                 = 3600
  records             = [data.azurerm_public_ip.public_ip.ip_address]
}

resource "azurerm_dns_cname_record" "name" {
  resource_group_name = var.resource_group_name
  zone_name           = azurerm_dns_zone.dns_zone.name
  name                = "*.${var.resource_group_name}"
  ttl                 = 3600
  record              = "${var.resource_group_name}.${var.dns_zone}"
}