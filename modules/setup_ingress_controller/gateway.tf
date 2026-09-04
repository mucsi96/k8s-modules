# The Gateway remains in a dedicated namespace with its TLS secret, while the
# k3s-packaged Traefik controller runs in kube-system. kubectl_manifest applies
# the custom resource without requiring its CRD schema during Terraform plan.
resource "kubectl_manifest" "gateway" {
  yaml_body = yamlencode({
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"
    metadata = {
      name      = local.gateway_name
      namespace = kubernetes_namespace_v1.gateway.metadata[0].name
    }
    spec = {
      gatewayClassName = "traefik"
      listeners = [{
        name     = local.gateway_listener_name
        port     = 8443
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

  depends_on = [kubectl_manifest.traefik_config]
}

resource "terraform_data" "gateway_ready" {
  triggers_replace = {
    gateway_uid           = kubectl_manifest.gateway.uid
    traefik_config_sha256 = sha256(kubectl_manifest.traefik_config.yaml_body)
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      KUBECONFIG_CONTENT = var.k8s_config
      GATEWAY_NAME       = local.gateway_name
      GATEWAY_NAMESPACE  = local.gateway_namespace
    }
    command = <<-EOT
      set -euo pipefail
      kubeconfig=$(mktemp)
      trap 'rm -f "$kubeconfig"' EXIT
      chmod 0600 "$kubeconfig"
      printf '%s' "$KUBECONFIG_CONTENT" > "$kubeconfig"
      kubectl --kubeconfig "$kubeconfig" --namespace "$GATEWAY_NAMESPACE" \
        wait "gateway/$GATEWAY_NAME" --for=condition=Accepted --timeout=10m
      kubectl --kubeconfig "$kubeconfig" --namespace "$GATEWAY_NAMESPACE" \
        wait "gateway/$GATEWAY_NAME" --for=condition=Programmed --timeout=10m
    EOT
  }

  depends_on = [kubectl_manifest.gateway]
}
