# Gateway API CRDs (standard channel, pinned). Traefik does not ship these — the
# kubernetesGateway provider needs them present at startup, and our Gateway /
# HTTPRoutes need them to apply. The bundle is vendored under files/ (rather than
# fetched at apply) for reproducible from-scratch applies with no network
# dependency. Standard channel is sufficient: we only use HTTPRoute and the
# RequestRedirect filter (both standard); no TLSRoute/TCPRoute.
# Source: https://github.com/kubernetes-sigs/gateway-api/releases/tag/v1.2.1
data "kubectl_file_documents" "gateway_api_crds" {
  content = file("${path.module}/files/gateway-api-standard-v1.2.1.yaml")
}

resource "kubectl_manifest" "gateway_api_crds" {
  for_each  = data.kubectl_file_documents.gateway_api_crds.manifests
  yaml_body = each.value

  # Gateway API CRDs are large; server-side apply avoids the
  # last-applied-configuration annotation exceeding the 262144-byte limit.
  server_side_apply = true
}
