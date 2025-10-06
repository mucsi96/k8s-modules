# Security

- [Manage your secrets with Terraform and Azure Key Vault](https://www.crayon.com/pl/resources/insights/manage-your-secrets-with-terraform-and-azure-key-vault/)
- [Demystifying Service Principals – Managed Identities](https://devblogs.microsoft.com/devops/demystifying-service-principals-managed-identities)
- [IPInfo](https://ipinfo.io/)
- [ASN IP ranges](https://github.com/ipverse/asn-ip)

# DNS

- [AzureDNS](https://cert-manager.io/docs/configuration/acme/dns01/azuredns/)
- [terraform-azure-aks-example](https://github.com/rgl/terraform-azure-aks-example)
- [Use Microsoft Entra Workload ID with Azure Kubernetes Service (AKS)](https://learn.microsoft.com/en-us/azure/aks/workload-identity-overview?tabs=javascript)

# Auth

- [Traefik - Replacing Basic Authentication with Azure SSO Using ForwardAuth](https://scottmckendry.tech/traefik-replacing-basic-authentication-with-sso/)

# Terraform

- [`terraform destroy`](https://developer.hashicorp.com/terraform/cli/commands/destroy) - Deprovisions everything tracked by the configuration. It's an alias for `terraform apply -destroy`, so it accepts most apply options and you can preview the effect with `terraform plan -destroy`.
- `terraform destroy -target <resource_address>` - Uses the `-target` option to destroy a specific resource and its dependencies without touching the rest of the workspace.
- [`terraform state rm`](https://developer.hashicorp.com/terraform/cli/commands/state/rm) - Removes Terraform's binding to remote objects without deleting them. Prefer `removed` blocks when possible and use flags like `-dry-run` or `-lock=false` to control the behavior.

# Cloudflare

- [Deploy Cloudflare Tunnel with Terraform](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/deployment-guides/terraform/)