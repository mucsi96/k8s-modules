# Kubernetes Dashboard

Deploys the [Kubernetes Dashboard](https://github.com/kubernetes/dashboard) to monitor cluster and node status.

## How it works

- The official `kubernetes-dashboard` Helm chart is installed in the `kubernetes-dashboard` namespace.
- The dashboard's built-in login screen is bypassed: a `dashboard-admin` ServiceAccount with `cluster-admin` rights is provisioned, a long-lived token is generated, and a Traefik `Middleware` injects an `Authorization: Bearer <token>` header on every incoming request.
- The dashboard is exposed under `dashboard.<dns_zone>` through the same Cloudflare Tunnel used by Traefik (the existing wildcard tunnel route covers it).
- A Cloudflare Zero Trust Access application protects the dashboard with the same Entra ID SSO identity provider and policy as the Traefik dashboard.

## Inputs

| Name | Description |
|------|-------------|
| `environment_name` | Azure resource group / environment name |
| `dns_zone` | Public DNS zone (the dashboard is exposed at `dashboard.<dns_zone>`) |
| `kubernetes_dashboard_chart_version` | Version of the `kubernetes-dashboard` Helm chart |
| `dashboard_subdomain` | Subdomain to expose the dashboard under (default: `dashboard`) |
| `cloudflare_account_id` | Cloudflare account ID |
| `cloudflare_access_identity_provider_id` | Cloudflare Zero Trust IdP ID (output from `setup_ingress_controller`) |
| `cloudflare_access_policy_id` | Cloudflare Zero Trust access policy ID (output from `setup_ingress_controller`) |
| `traefik_namespace` | Namespace where Traefik is installed |
| `wait_for` | Optional dependency handle |
