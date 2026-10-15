output "document_middleware" {
  value = "${helm_release.auth.name}-document"
}

output "api_middleware" {
  value = "${helm_release.auth.name}-api"
}
