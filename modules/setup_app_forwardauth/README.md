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

## Published charts

The central pin is published
[**7.0.0**](https://github.com/mucsi96/k8s-helm-charts/releases/tag/oauth2-proxy-forwardauth-7.0.0).
The cookie name is fixed to `__Host-session`; application charts own their route
Middleware. Published application charts are client-app **26.0.0**,
static-client-app **2.0.0**, spring-app **34.0.0**, go-app **5.0.0**,
node-app **24.0.0** and rust-app **4.0.0**.

Client/API deployments need namespace-scoped `traefik.io/middlewares` permissions;
`create_app_namespace` supplies those plus same-namespace `traefikservices`
permissions for external static origins. UI routes/config injection stay client-owned.
Enable ingress `enable_index_config` before deploying runtime injection. Validate
Terraform without applying infrastructure.
