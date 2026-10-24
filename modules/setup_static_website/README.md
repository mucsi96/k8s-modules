# Static website storage

Creates a dedicated Standard/LRS account with static website hosting, index.html,
TLS 1.2 minimum, disabled shared keys and OAuth-default management. `$web` holds
index.html; the public-read `assets` Blob container holds browser assets. Account
public access is enabled for anonymous blob reads, without anonymous listing.
Upload only public build resources. No SPA 404 fallback is set.

Inputs: globally unique `name`, `resource_group_name`, `location`, and the existing
app `deploy_principal_id`, plus HTTPS `app_origin` for CORS. Output
`deployment_config` supplies `account_name`, document `hostname`, and
`assets_base_url`. The deploy identity receives Storage Blob Data Contributor
separately scoped to `$web` and `assets`. The provisioning provider must use
`storage_use_azuread = true` and have storage service-property management access.

Terraform owns storage and permissions; the application pipeline owns blobs.
Use the document-only `static-client-app` chart's `staticOrigin` value and
enable external origins in the ingress module. The app namespace role permits
same-namespace TraefikServices.
The existing Web registration/session and API validation are retained.

Azure website endpoints do not support CORS. Browser assets use the Blob endpoint;
Blob CORS allows only `app_origin` with GET/HEAD/OPTIONS and a one-hour preflight
cache. The gateway fetches documents from the website endpoint over verified HTTPS.
