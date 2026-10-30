resource "kubectl_manifest" "faro_client_httproute" {
  count = nonsensitive(length(var.faro_client_hostnames) > 0 ? 1 : 0)

  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "faro-client-ingest"
      namespace = kubernetes_namespace_v1.logging.metadata[0].name
    }
    spec = {
      parentRefs = [{
        group       = "gateway.networking.k8s.io"
        kind        = "Gateway"
        name        = var.gateway_parent_ref.name
        namespace   = var.gateway_parent_ref.namespace
        sectionName = var.gateway_parent_ref.section_name
      }]
      hostnames = var.faro_client_hostnames
      rules = [{
        matches = [for method in ["POST", "OPTIONS"] : {
          path   = { type = "Exact", value = var.faro_client_path }
          method = method
        }]
        filters = [
          {
            type = "RequestHeaderModifier"
            requestHeaderModifier = {
              remove = ["Authorization", "Cookie", "X-XSRF-TOKEN", "X-Auth-Request-Access-Token"]
            }
          },
          {
            type = "URLRewrite"
            urlRewrite = {
              path = { type = "ReplaceFullPath", replaceFullPath = "/collect" }
            }
          },
          {
            type = "ResponseHeaderModifier"
            responseHeaderModifier = {
              set    = [{ name = "Cache-Control", value = "no-store" }]
              remove = ["Authorization", "X-Auth-Request-Access-Token"]
            }
          }
        ]
        backendRefs = [{ name = local.faro_alloy_release, port = local.faro_port }]
      }]
    }
  })

  depends_on = [helm_release.faro_alloy]
}
