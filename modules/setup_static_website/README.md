# Static website storage

Creates a dedicated Standard/LRS account with static website hosting, index.html,
TLS 1.2 minimum, disabled shared keys and OAuth-default management. Blob-container
anonymous access is disabled; Azure's static website endpoint remains publicly
readable by design. Upload only public build resources. No SPA 404 fallback is set.

Inputs: globally unique `name`, `resource_group_name`, `location`, and the existing
app `deploy_principal_id`. Output `deployment_config` supplies `account_name` and
`hostname` to the app deploy script. The deploy identity receives Storage Blob Data
Contributor only on `$web`. The provisioning provider must use
`storage_use_azuread = true` and have storage service-property management access.

Terraform owns storage and permissions; the application pipeline owns blobs.
Use the published `static-client-app` **1.0.0** chart's `staticOrigin` value and
enable external origins in the ingress module. The app namespace role permits
same-namespace TraefikServices.
The existing Web registration/session and API validation are retained.
