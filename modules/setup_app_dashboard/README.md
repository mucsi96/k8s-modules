# Observatory

Provisions the Gin/GORM/Angular app's inventory, PostgreSQL `observatory` schema
and role, source GitHub/DB Secrets, collector/deployer RBAC, Entra registrations,
and ingress NetworkPolicy. The app pipeline deploys `mucsi96/go-app` **1.0.0**
and `mucsi96/client-app` **22.0.0**.

Authentication follows `setup_hello_app` (skeleton-app): shared `register_api`
and `register_spa`, authorization code + PKCE, bearer API JWTs, `api-access`
scope, and the `readApps` role assigned to the owner. Additional users need that
role. Public tenant/SPA/API IDs and Faro URL are stored in the inventory ConfigMap
and exposed by `/api/environment`. Local frontend redirect: `http://localhost:4270/`.

The Go chart owns the `observatory` ServiceAccount, whose name is also used by
the workload federation and read-only collector RoleBindings. It configures
`SERVER_PORT=8080`, `MANAGEMENT_PORT=8082`, `BASE_PATH=/api`, and management health
probes. The frontend runs on 8000. Chart HTTPRoutes attach to the platform's
`traefik/traefik` Gateway, `websecure` listener. Terraform does not own these routes.
`ingress_controller_namespace` identifies the actual Traefik pod namespace for
the NetworkPolicy, which may differ from the Gateway namespace.

The app deploy identity reads the platform's `k8s-oidc-config` Key Vault secret.
Its Kubernetes role is limited to the Observatory namespace and includes the
Deployment/Service/Secret/ServiceAccount/HTTPRoute resources Helm requires.
Runtime chart values are assembled from the Terraform-managed inventory and
source Secrets by the application's deploy script. Terraform itself does not
own Helm release state or application image versions.

## Migration

First provision the new API/SPA registrations, inventory, DB Secret/schema, and
deployment role. Deploy the new application images with the pinned charts,
using Helm's `--take-ownership` to adopt existing resource names. Then apply the
full Terraform configuration to remove the old proxy and legacy route and update
the NetworkPolicy. The `removed` blocks preserve the old Deployment, Service and
ServiceAccount during handoff; the shared Microsoft Graph service principal has
a `moved` block into the SPA registration. See the app README for commands.

Removed proxy-specific inputs: `valid_email`, `oauth2_proxy_chart_version`,
`oauth2_proxy_image_version`, `session_redis`, and `gateway_parent_ref`.
New inputs include `database`, `client_log_url`, `k8s_oidc_issuer_url`, and
`ingress_controller_namespace`.
