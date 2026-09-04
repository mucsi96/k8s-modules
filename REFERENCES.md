# Security

- [Manage your secrets with Terraform and Azure Key Vault](https://www.crayon.com/pl/resources/insights/manage-your-secrets-with-terraform-and-azure-key-vault/)
- [Demystifying Service Principals – Managed Identities](https://devblogs.microsoft.com/devops/demystifying-service-principals-managed-identities)
- [IPInfo](https://ipinfo.io/)
- [ASN IP ranges](https://github.com/ipverse/asn-ip)
- [Workload identity federation](https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation)
- [About security hardening with OpenID Connect](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/about-security-hardening-with-openid-connect) - GitHub Actions OIDC subject claim formats; repos created after 2026-07-15 send immutable `owner@ID/repo@ID` subjects.
- [Azure AD Workload Identity](https://azure.github.io/azure-workload-identity/docs/introduction.html)

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
- [HashiCorp HTTP provider](https://registry.terraform.io/providers/hashicorp/http/latest/docs) - Read-only API data source used for Netcup discovery.

# Netcup And k3s

- [Netcup SCP REST API](https://www.netcup.com/en/helpcenter/documentation/server/rest-api)
- [Netcup SCP OpenAPI document](https://www.servercontrolpanel.de/scp-core/api/v1/openapi)
- [Netcup server images](https://www.netcup.com/en/helpcenter/documentation/server/media)
- [Netcup firewall](https://www.netcup.com/en/helpcenter/documentation/server/firewall)
- [k3s configuration](https://docs.k3s.io/installation/configuration)
- [k3s packaged components](https://docs.k3s.io/installation/packaged-components)
- [k3s HelmChartConfig](https://docs.k3s.io/helm#customizing-packaged-components-with-helmchartconfig)
- [Kubernetes structured authentication](https://kubernetes.io/docs/reference/access-authn-authz/authentication/#using-authentication-configuration)

# Cloudflare

- [Cloudflare Origin CA certificates](https://developers.cloudflare.com/ssl/origin-configuration/origin-ca/)
- [SSO integration](https://developers.cloudflare.com/cloudflare-one/identity/idp-integration/)
- [Configure Cloudflare with Microsoft Entra ID for secure hybrid access](https://learn.microsoft.com/en-us/entra/identity/enterprise-apps/cloudflare-integration)
