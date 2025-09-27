output "endpoint" {
  value = azurerm_ai_services.ai_services.endpoint
}

output "api_version" {
  value = "2024-08-01-preview"
}

output "id" {
  value = azurerm_ai_services.ai_services.id
}

output "deployment" {
  value = azurerm_cognitive_deployment.openai_deployment.name
}
