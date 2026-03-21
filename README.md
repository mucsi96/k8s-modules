# aks-modules
Terraform modules for Azure cloud deployment

## Prerequisites

### Azure Key Vault Secrets

The following secrets must exist in the Azure Key Vault (named after the `environment_name` variable) before creating the cluster:

| Secret Name | Description |
|---|---|
| `host` | SSH host address of the target Linux server |
| `ssh-user-name` | SSH username for server access |
| `ssh-initial-password` | Initial SSH password for server access |
| `ssh-initial-port` | Initial SSH port number |
| `dns-zone` | DNS zone domain used by all applications |
| `letsencrypt-email` | Email address for Let's Encrypt certificate registration |
| `cloudflare-zone-id` | Cloudflare zone ID for DNS management |
| `cloudflare-account-id` | Cloudflare account ID |
| `cloudflare-api-token` | Cloudflare API token for DNS and tunnel management |
| `cloudflare-team-domain` | Cloudflare Zero Trust team domain |
| `authorized-as` | Authorized identity/email for SSO access policies |
| `twingate-api-token` | Twingate API token for zero-trust network access |
| `twingate-network` | Twingate network identifier |

## Requirements
