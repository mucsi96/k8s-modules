resource "azurerm_ai_services" "ai_services" {
  name                         = var.resource_group_name
  location                     = var.location
  resource_group_name          = var.resource_group_name
  sku_name                     = "S0"
  local_authentication_enabled = false
  custom_subdomain_name        = "ibari-${var.resource_group_name}"
}

resource "azurerm_cognitive_deployment" "openai_deployment" {
  name                 = var.resource_group_name
  cognitive_account_id = azurerm_ai_services.ai_services.id

  model {
    format  = "OpenAI"
    name    = "gpt-4o"
    version = "2024-08-06"
  }

  sku {
    name     = "GlobalStandard"
    capacity = 5
  }
}
