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
| `twingate-api-token` | Twingate API token with Read, Write & Provision permissions |
| `twingate-network` | Twingate network name (e.g. `mynetwork` from `mynetwork.twingate.com`) |
| `github-token` | GitHub personal access token with `repo` scope for setting Actions secrets |

## Running a Second Environment on Hetzner CX42

The configuration supports running a parallel copy of the stack on a separate VPS so you can switch traffic between the two by editing a single Cloudflare DNS record.

### Target VPS

- Hetzner Cloud **CX42** (8 vCPU, 16 GB RAM, 160 GB NVMe, Ubuntu 24.04)
- Listed price **€16.40/month**, which is the intended cap for this environment
- Any equivalent VPS with Ubuntu 24.04 works as long as the monthly cost stays within the cap

### Provision the Secondary Environment

1. Create the Hetzner CX42 VPS with Ubuntu 24.04. Record its IP, SSH user, initial password, and initial SSH port.
2. Pick a distinct `environment_name` (for example `p07`) for the secondary. Run `./scripts/init.sh <environment_name>` to create a dedicated Azure resource group, Key Vault, storage account, and `backend.tf`. Each environment has its own Terraform state, so the two never conflict.
3. Populate the secondary Key Vault with the same secret set documented above, but pointing at the Hetzner host:
   - `host`, `ssh-user-name`, `ssh-initial-password`, `ssh-initial-port` → Hetzner VPS values
   - All other secrets (`dns-zone`, `letsencrypt-email`, `cloudflare-*`, `authorized-as`, `twingate-*`, `github-token`) can be the same values used by the primary since both environments share the Cloudflare zone and DNS zone.
4. Apply with the wildcard DNS record disabled so it does not fight the primary for the same `*` CNAME record:

   ```
   terraform apply -var="manage_wildcard_dns_record=false"
   ```

   The primary environment keeps `manage_wildcard_dns_record = true` (the default) and owns the wildcard record.

### Switching Traffic

After a successful apply, `terraform output cloudflare_tunnel_cname_target` prints the CNAME content for that environment (e.g. `<tunnel-id>.cfargotunnel.com`).

To cut traffic over to a different environment, edit the single wildcard `*` CNAME record in the Cloudflare dashboard and set its **Content** to the target printed by that environment's output. Keep it **Proxied**. Propagation is effectively immediate because Cloudflare serves the record.

No other changes are needed — both tunnels stay up, and the DNS record alone decides which environment receives requests.

## Requirements
