# setup_app_forwardauth

Pins the published `oauth2-proxy-forwardauth` chart **3.0.0** with a per-service Web client,
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

Convert the existing client's redirect type with `register_spa.web_redirect_uris`:
the Azure application/service-principal addresses and API preauthorization stay
stable, while the SPA block is removed, a confidential credential is created,
and Web-client assignment becomes mandatory. The owner is always assigned;
Cooking additionally passes its household user IDs. Existing API role and
workload-identity resources must remain intact.

For a staged rollout, set `retain_spa_redirects = true` temporarily: preprovision
the Web client/proxy while existing SPA tabs can still authenticate. Deploy the
cookie-auth builds, then switch it to false to remove the SPA redirect type.

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

`public_api_routes` provisions exact public GET HTTPRoutes for non-sensitive
bootstrap. Hello/Cooking use this for `/api/environment?returnTo=<relative-path>`.
That endpoint checks the session through the internal proxy API, relays only
session cookie updates and discards token-bearing headers. It returns config
when authenticated or a server-selected redirect to `/oauth2/start`. External
return targets are rejected. Protected API routes validate JWTs, scopes and roles.
The proxy renews sessions; a lost/unrenewable session re-enters login on the next
page load. There is no SPA auth UI or popup reauthentication.

The chart pin is centralized in this module; callers do not need a version
placeholder. Release asset and Helm repository metadata were verified for
[3.0.0](https://github.com/mucsi96/k8s-helm-charts/releases/tag/oauth2-proxy-forwardauth-3.0.0).

When upgrading an existing API-app auth release from 2.0.0, first remove document
auth filters from its frontend HTTPRoute: chart 3.0.0 removes the unused document
Middleware/policy in API mode. All five stock control routes remain available.
New pilot installations can preprovision with `retain_spa_redirects = true`
before deploying the matching server/bootstrap and public frontend builds.

`machine_routes` adds exact path/method HTTPRoutes directly to an API Service,
without browser ForwardAuth. Backend token/role checks remain mandatory. Cooking
uses `/api/integrations/recipes/import` for its email/background JWT contract.

Application access is enforced by the API's JWT/scope/role checks and mutation
Origin validation.
Existing app labels, Services, workload identities, PVCs and database schemas
are retained. Redis is shared, not provisioned by each module.

## Grafana and other Terraform-managed services

For p07 Grafana, the existing Web registration can supply the client credentials:

```hcl
module "grafana_auth" {
  source = "../setup_app_forwardauth"

  name                = "grafana"
  namespace           = "monitoring"
  mode                = "email-header"
  hostname            = var.grafana_hostname
  tenant_id           = var.tenant_id
  client_id           = var.grafana_client_id
  client_secret       = var.grafana_client_secret
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
the existing Helm release/cookie state addresses and updating its current
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
