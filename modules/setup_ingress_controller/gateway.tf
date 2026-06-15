# The single shared Gateway. One HTTPS listener on port 8000 — the container
# port of Traefik's "web" entrypoint (hostPort 443 maps host:443 → :8000), which
# Traefik associates with the listener by matching port number. TLS terminates
# here with the Cloudflare Origin CA cert (origin_certificate.tf); the cert
# secret is in this namespace, so no ReferenceGrant is needed.
#
# allowedRoutes.namespaces.from = All lets HTTPRoutes in any namespace attach
# (the infra namespaces here plus the app namespaces), replacing the Traefik
# kubernetesCRD provider's old allowCrossNamespace flag.
resource "kubectl_manifest" "gateway" {
  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = "traefik"
      namespace = kubernetes_namespace_v1.traefik.metadata[0].name
    }
    spec = {
      gatewayClassName = "traefik"
      listeners = [{
        name     = "websecure"
        port     = 8000
        protocol = "HTTPS"
        tls = {
          mode = "Terminate"
          certificateRefs = [{
            name = kubernetes_secret_v1.origin_tls.metadata[0].name
          }]
        }
        allowedRoutes = {
          namespaces = {
            from = "All"
          }
        }
      }]
    }
  })

  depends_on = [helm_release.traefik]
}
