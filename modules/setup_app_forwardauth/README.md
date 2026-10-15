# setup_app_forwardauth

Deploy the published `oauth2-proxy-forwardauth` chart with a per-app Web client,
platform Redis and persisted cookie secret. Only the proxy credential/Redis
Secret references enter Helm values; secret hashes trigger rollouts on rotation.
Keep this module platform-owned so application CI never needs auth credentials.

Convert the existing client's redirect type with `register_spa.web_redirect_uris`:
the Azure application/service-principal addresses and API preauthorization stay
stable, while the SPA block is removed, a confidential credential is created,
and Web-client assignment becomes mandatory. The owner is always assigned;
Cooking additionally passes its household user IDs. Existing API role and
workload-identity resources must remain intact.

For a staged rollout, set `retain_spa_redirects = true` temporarily: preprovision
the Web client/proxy while existing SPA tabs can still authenticate. Deploy the
cookie-auth builds, then switch it to false to remove the SPA redirect type.

Hello/Cooking opt in using their optional `forward_auth` input. Supply a published
chart version, shared Redis descriptor, trusted Traefik source CIDRs and Gateway
reference. Enable `setup_ingress_controller.enable_forward_auth` first. Update
the application charts' `routeFilters` and deploy cookie-auth-capable clients
and exact-Origin-protected APIs as one coordinated rollout.

The chart publishes document/API JSON policies in its non-secret
`<release>-route-filters` ConfigMap. App deployment jobs read those policies;
identity stripping and cache controls are standard Gateway API header filters.
Only the two ForwardAuth authenticators require Traefik Middleware resources.

`machine_routes` adds exact path/method HTTPRoutes directly to an API Service,
without browser ForwardAuth. Backend token/role checks remain mandatory. Cooking
uses `/api/integrations/recipes/import` for its email/background JWT contract.

The `protected_apps` policies admit Traefik only on app ports and monitoring on
management ports. Existing app labels, Services, workload identities, PVCs and
database schemas are retained. Redis is shared, not provisioned by each module.

Validation must not apply infrastructure. See p07's ForwardAuth rollout document
for publication order and the unpublished-module handoff.
