# aks-modules
Terraform modules for Azure cloud deployment

## Prerequisites

### Azure Key Vault Secrets

The following secrets must exist in the Azure Key Vault (named after the `environment_name` variable) before creating the cluster:

| Secret Name | Description |
|---|---|
| `host` | SSH host address of the target Linux server (only required when using `setup_cluster`) |
| `ssh-user-name` | SSH username for server access (only required when using `setup_cluster`) |
| `ssh-initial-password` | Initial SSH password for server access (only required when using `setup_cluster`) |
| `ssh-initial-port` | Initial SSH port number (only required when using `setup_cluster`) |
| `hcloud-token` | Hetzner Cloud API token with read/write permissions (only required when using `setup_hetzner_cluster`) |
| `dns-zone` | DNS zone domain used by all applications |
| `letsencrypt-email` | Email address for Let's Encrypt certificate registration |
| `cloudflare-zone-id` | Cloudflare zone ID for DNS management |
| `cloudflare-account-id` | Cloudflare account ID |
| `cloudflare-api-token` | Cloudflare API token for DNS and tunnel management |
| `cloudflare-team-domain` | Cloudflare Zero Trust team domain |
| `authorized-as` | Authorized identity/email for SSO access policies |
| `twingate-api-token` | Twingate API token with Read, Write & Provision permissions |
| `twingate-network` | Twingate network name (e.g. `mynetwork` from `mynetwork.twingate.com`) |
| `github-token` | GitHub personal access token with `repo` scope for setting Actions secrets |

## Cluster modules

Two interchangeable modules provision the single-node MicroK8s control plane. They expose the same outputs (`k8s_host`, `k8s_client_certificate`, `k8s_client_key`, `k8s_cluster_ca_certificate`, `oidc_issuer_url`, ...) so downstream modules stay unchanged.

- `modules/setup_cluster` — targets an existing Linux host (local machine / bare metal) reachable over SSH with password authentication.
- `modules/setup_hetzner_cluster` — provisions a Hetzner Cloud server (default type `cx42`, image `ubuntu-24.04`) via the `hcloud` provider and runs the same MicroK8s + OIDC playbooks on it. Intended for a separate deployment target with its own Terraform state.

## Requirements
