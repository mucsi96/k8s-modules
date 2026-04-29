# aks-modules
Terraform modules for Azure cloud deployment

## Prerequisites

### Azure Key Vault Secrets

The following secrets must exist in the Azure Key Vault (named after the `environment_name` variable) before creating the cluster:

| Secret Name | Description |
|---|---|
| `host` | SSH host address of the target Linux server (only required when **not** provisioning with Hetzner; otherwise it is created by Terraform) |
| `ssh-user-name` | SSH username for server access (only required when **not** provisioning with Hetzner) |
| `ssh-initial-password` | Initial SSH password for server access (only required when **not** provisioning with Hetzner) |
| `ssh-initial-port` | Initial SSH port number (only required when **not** provisioning with Hetzner) |
| `hetzner-api-token` | Hetzner Cloud API token (read & write) — **only** required when `provision_with_hetzner = true` |
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

## Environments

The configuration supports two server provisioning modes, selected via the
`provision_with_hetzner` variable:

| Mode | Variable | Used by |
|---|---|---|
| **External host** (default) | `provision_with_hetzner = false` | `p06` — assumes the Linux host already exists; SSH access details are read from the Key Vault secrets above. |
| **Hetzner Cloud** | `provision_with_hetzner = true`  | `p07` — Terraform provisions a Hetzner Cloud server end-to-end. |

### Hetzner Cloud (p07)

`p07` is fully provisioned on Hetzner Cloud using the
[`provision_hetzner_server`](modules/provision_hetzner_server) module. The
default plan is **CX42** (8 vCPU shared Intel, 16 GB RAM, 160 GB SSD —
~€16/month including the IPv4 address) deployed in the Falkenstein (`fsn1`)
datacenter.

Tunable inputs (set via Terraform variables or `terraform.tfvars`):

| Variable | Default | Description |
|---|---|---|
| `provision_with_hetzner` | `false` | Enable the Hetzner provisioning flow. |
| `hetzner_server_type`    | `cx42`  | Hetzner server type (e.g. `cx22`, `cx32`, `cx42`, `cx52`). |
| `hetzner_location`       | `fsn1`  | Hetzner datacenter (`fsn1`, `nbg1`, `hel1`, `ash`, `hil`, …). |
| `hetzner_username`       | `ubuntu`| Initial sudo user created via cloud-init. |

Bootstrapping a fresh `p07`:

```bash
# 1. Provision the Azure backend (resource group, key vault, storage account, etc.)
#    and write a terraform.auto.tfvars with provision_with_hetzner = true.
./scripts/init.sh p07 --hetzner

# 2. Populate the Key Vault with the Hetzner Cloud API token (and the usual
#    dns-zone, cloudflare-*, twingate-*, github-token, letsencrypt-email, etc.):
az keyvault secret set \
  --vault-name p07 \
  --name hetzner-api-token \
  --value "<your-hetzner-cloud-api-token>"

# 3. Apply
AZURE_KEYVAULT_NAME=p07 ./scripts/install_dependencies.sh
./scripts/create.sh
```

Tearing it down:

```bash
AZURE_KEYVAULT_NAME=p07 PROVISION_WITH_HETZNER=true ./scripts/destroy.sh
```

## Requirements
