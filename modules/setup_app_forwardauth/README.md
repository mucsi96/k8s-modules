# setup_app_forwardauth

Pins the published `oauth2-proxy-forwardauth` chart **5.0.0** with a per-service Web client,
platform Redis and persisted cookie secret. Only the proxy credential/Redis
Secret references enter Helm values; secret hashes trigger rollouts on rotation.
Keep this module platform-owned so application CI never needs auth credentials.

## Authentication modes

| `mode` | Consumer | Forwarded identity | API registration |
| --- | --- | --- | --- |
| `api-token` (default) | Our JWT-protected APIs | Cooking/Hello API access token | `api_client_id` required |
| `email-header` | Grafana and compatible services | `X-Auth-Request-Email` | Not required |
| `login-gate` | Services needing authenticated access only | No identity credentials | Not required |

Each mode uses an assigned confidential Entra Web client and shared Redis.
The module does not depend on Angular, our API implementation or app deployment
scripts. Terraform-managed services consume its route policies directly.

## Public frontend and app deployment

Use the dedicated `register_web` module to provision the confidential client.
Hello/Cooking use it exclusively when `forward_auth` is set. The legacy
`register_spa` module now configures only SPA clients and is selected only when
ForwardAuth is disabled. The Web module owns its credential, OIDC consent, API
preauthorization and required owner/household assignments.

Existing installations adopt the same registration using the documented module
and resource state moves in [register_web](../register_web/README.md). IDs and
existing password keys/values are retained. This is a Web-only cutover: deploy
the cookie-auth app builds first, remove `retain_spa_redirects` from environment
inputs, then apply the matching environment-level migration blocks. Complete both
pilot app cutovers before advancing p07 to the Web-only migration release.

Hello/Cooking opt in using their optional `forward_auth` input. Supply the
shared Redis descriptor, trusted Traefik source CIDRs and Gateway
reference. Enable `setup_ingress_controller.enable_forward_auth` first. Apply
`routeFilters` only to the API chart. Frontend HTML, bundles and SPA routes are
public. Before Angular starts, the environment controller checks the proxy
session and returns configuration or a generic `redirectTo` instruction. The
bootstrap loader follows that instruction without OAuth/session logic. The SPA
has no auth service, auth interceptor, sign-in/sign-out controls or route guards.
An independent profile resource reads token-free `/oauth2/userinfo` to display
the user name in the header context menu. Deploy clients and APIs together.

The chart publishes JSON policies in its non-secret `<release>-route-filters`
ConfigMap. Terraform reads that ConfigMap after the auth release is ready.
The sole module output, `deployment_config`, contains only consumed fields:

| Field | Consumer |
| --- | --- |
| `release_name` | App deployment preflight, e.g. `cooking-oauth2-proxy` |
| `route_filters.api` | Protected API HTTPRoute |
| `route_filters.document` | Protected service UI HTTPRoute; only present in email-header/login-gate modes |
| `session_url` | App server's `AUTH_SESSION_URL`; private `/oauth2/auth` session check, API mode only |
| `sign_in_url` | App server's `AUTH_SIGN_IN_URL`; public `/oauth2/start`, API mode only |

Hello/Cooking consume that output through `setup_app_base.deployment_secrets`,
which writes `forward-auth-config` to their app-specific Azure Key Vault and
grants the GitHub deployment identity read access to that secret. `deploy.sh`
reads the release name for its preflight, `route_filters.api` for the server
chart, and the two bootstrap URLs for server environment variables. It does not
read the Kubernetes ConfigMap or Terraform state. No document
policy or unused resource-name outputs are exported for these apps.

`excluded_routes` supplies one list of explicit `path`, `method`, `service` and
`port` entries as the chart's `excludedRoutes` value. Helm owns the generated
HTTPRoute, alongside its OAuth and authentication resources. There is no
Terraform routing manifest or extra `kubectl` provider in this module.
Hello/Cooking exclude `GET /api/environment` for bootstrap.
That endpoint checks the session through the internal proxy API, relays only
session cookie updates and discards token-bearing headers. It returns config
when authenticated or a server-selected redirect to `/oauth2/start`. External
return targets are rejected. Protected API routes validate JWTs, scopes and roles.
The proxy renews sessions; a lost/unrenewable session re-enters login on the next
page load. There is no SPA auth UI or popup reauthentication.

The chart pin is centralized in this module; callers do not need a version
placeholder. Release asset and Helm repository metadata were verified for
[5.0.0](https://github.com/mucsi96/k8s-helm-charts/releases/tag/oauth2-proxy-forwardauth-5.0.0).

Chart 5.0.0 reads API/login-gate identity from the verified ID token without
attempting Graph profile lookups for missing optional claims. It also routes the
proxy's static CSS/font assets so stock login/error pages render correctly.

When upgrading an existing API-app auth release from 2.0.0, first remove document
auth filters from its frontend HTTPRoute: chart 5.0.0 omits the unused document
Middleware/policy in API mode. All five stock control routes remain available.
New installations provision a Web-only client. Existing pilot installations
complete app cutover before adopting the dedicated Web registration module.

The same `excluded_routes` list contains Cooking's
`POST /api/integrations/recipes/import` integration route. Exclusion skips only
browser ForwardAuth: its backend still requires the caller's bearer token and
role. The bootstrap handler checks the proxy session itself. Caller headers and
cookies are preserved, and no path-prefix bypass is created.

Application access is enforced by the API's JWT/scope/role checks and mutation
Origin or CSRF-token validation.
Existing app labels, Services, workload identities, PVCs and database schemas
are retained. Redis is shared, not provisioned by each module.

## Grafana and other Terraform-managed services

For a new Grafana-style service, create the assigned Web client without an API
registration and pass its credentials to ForwardAuth:

```hcl
module "grafana_web" {
  source = "../register_web"

  display_name  = "Grafana Web"
  owner         = var.owner
  redirect_uris = ["https://${var.grafana_hostname}/oauth2/callback"]
}

module "grafana_auth" {
  source = "../setup_app_forwardauth"

  name                = "grafana"
  namespace           = "monitoring"
  mode                = "email-header"
  hostname            = var.grafana_hostname
  tenant_id           = var.tenant_id
  client_id           = module.grafana_web.client_id
  client_secret       = module.grafana_web.client_secret
  trusted_proxy_cidrs = var.trusted_proxy_cidrs
  session_redis       = var.session_redis
  gateway_parent_ref  = var.gateway_parent_ref
}
```

The owning service module's HTTPRoute consumes
`module.grafana_auth.deployment_config.route_filters.document` for `/` and
`.route_filters.api` for `/api`. Both rules forward directly to
`victoria-metrics-k8s-stack-grafana:80`. Grafana uses its existing
`auth.proxy.header_name = X-Auth-Request-Email` configuration; sign-in assignment
remains enforced by the existing Entra Web registration. Use `login-gate` for
a service that needs the session check but no identity header.

Adopting this in the existing Grafana installation also requires preserving
the existing Web-registration, Helm-release and cookie state addresses and updating its current
HTTPRoute backend from the reverse proxy to the Grafana Service.

## Automatic login and control-route ownership

| URL | Handler | Initiator |
| --- | --- | --- |
| `/oauth2/start` | Stock oauth2-proxy starts OIDC login | Server-selected bootstrap redirect, or protected service login flow |
| `/oauth2/sign_in` | Stock proxy sign-in page | Stock proxy login/error flow |
| `/oauth2/callback` | Stock proxy exchanges the authorization code | Entra redirects to the registered Web callback |
| `/oauth2/userinfo` | Stock proxy token-free session identity | SPA header profile and service integrations |
| `/oauth2/sign_out` | Stock proxy local logout | Stock endpoint remains available; no SPA logout control |

The auth chart's `oauth-route.yaml` forwards these exact host/path matches from
Traefik to the proxy. They do not require a prior application session. Terraform
registers the callback URI on the Entra Web client. Entra authorization/token
URLs are discovered from the configured issuer. `/oauth2/auth` is an internal
ForwardAuth target and is not exposed by that public route.

All modes expose these five exact control routes. The SPAs use userinfo only
for display data, with login/session handling kept server-side. Sign-out clears
the local proxy session rather than the Entra SSO session; a new page load can
therefore sign in automatically again through SSO.
For future storage-hosted frontends, keep `/api` and `/oauth2` routed to the
cluster at the edge while serving static paths from storage. The storage
account itself does not forward those requests.

Validation must not apply infrastructure. See p07's ForwardAuth rollout document
for publication order and the unpublished-module handoff.
