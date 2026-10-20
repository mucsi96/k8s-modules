# setup_app_forwardauth

Platform-owned stock oauth2-proxy with a confidential Entra Web client, shared
Redis and persisted per-app cookie secret. Credentials remain in Kubernetes
Secrets; checksum annotations roll the proxy on rotation.

The app charts own all application authentication Middleware and filters. This
module exports only a non-secret proxy reference, not generated policies:

```json
{
  "release_name": "hello-oauth2-proxy",
  "auth": {
    "proxyService": "hello-oauth2-proxy",
    "proxyPort": 80,
    "mode": "api-token"
  }
}
```

`fullnameOverride` makes the descriptor match the proxy Service without querying
Helm-generated resources. All app hosts use the fixed `__Host-session` name;
the host-only cookie and per-app secrets keep sessions separate. There is no
cookie-name field in the deployment descriptor.
App modules publish `deployment_config` as `forward-auth-config` through
`setup_app_base.deployment_secrets`. Deployment reads `.auth` and supplies it to
client/API chart `auth`. The client performs a document check; backend charts
perform an API check. The release name supports deployment preflight.

There is no policy ConfigMap/readback, document-auth toggle or filter-list handoff.
Hello publishes public runtime JSON separately as `client-runtime-config`, which
deployment passes to the client chart. Proxy credentials never belong there.

## Modes and ownership

| Mode | Proxy identity output | API registration |
| --- | --- | --- |
| `api-token` | App-API access token | Required |
| `email-header` | Verified email | Not required |
| `login-gate` | No identity | Not required |

The app chart's mode must match the proxy. Static client routes forward no
identity to their origin in any mode. APIs retain JWT/scope/role and mutation
CSRF checks. Use `register_web` for confidential callbacks, required assignment,
OIDC consent and optional API preauthorization; business roles remain separate.

The proxy chart owns the exact five `/oauth2` control routes and GET/HEAD static
assets. `/oauth2/auth` and the token-bearing proxy root remain private. The
`excluded_routes` input retains exact path/method bypasses for independently
authenticated integrations; it never makes their handlers unauthenticated.

## Publication and existing consumers

The central pin is still published **5.0.0** while the new app/proxy charts await
release. The module explicitly configures `__Host-session` on chart 5 to match
the new app middleware. This cookie rename requires a new sign-in. First
publish compatible app charts and expose the new deployment descriptor; convert
all consuming app routes and discard their old Helm `routeFilters` values. New
app charts accept `auth` only and reject nonempty legacy filter lists. Only then advance
the proxy-chart pin to the verified release that removes old policy resources.
Do not remove proxy-owned middleware while live routes still reference it.

Existing deployment scripts expecting `.route_filters` must be updated before
adopting this module contract. p07 Cooking intentionally stays on its old module
pin until that app cutover. The new Cooking module retains its backend bootstrap
URLs in its own deployment configuration until its separate UI migration.

Client/API deployments need namespace-scoped `traefik.io/middlewares` permissions;
`create_app_namespace` supplies those without granting other Traefik resources
or cluster permissions. UI routes/config injection always stay client-owned.
Enable ingress `enable_index_config` before deploying runtime injection. Validate
Terraform without applying infrastructure.
