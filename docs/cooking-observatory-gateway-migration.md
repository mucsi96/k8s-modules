# Cooking and Observatory gateway migration

Release these module changes before deploying the matching app MRs. Callers must
pin the resulting published release; v-93 does not provide these contracts.

Cooking now publishes `client-runtime-config` and the standard `forward-auth-config`
descriptor. Cooking uses only its browser-authenticated import endpoints; no
integration-import or environment-bootstrap bypass remains. Database, PVs and
workload identity are unchanged.

Observatory retains Rust/React. Its caller replaces `valid_email`, proxy version,
`session_redis`, `gateway_parent_ref`, and `kubeconfig_secret_id` inputs with:

- `azure_location`, `k8s_oidc_config`, `k8s_oidc_issuer_url`
- `client_log_url` set to `https://<app-host>/_telemetry/collect`
- `ingress_controller_namespace`
- `forward_auth` containing trusted proxy CIDRs, Redis and Gateway parent reference

The caller must also provision the same-origin telemetry route in the Observatory
namespace, matching Skeleton. The app vault contains scoped deployment secrets;
Helm owns the API/client resources and namespace Middleware. Existing inventory
and GitHub Secret remain platform-owned. API registration addresses and the
`observatory-api-workload-identity` account match the previously applied direct-JWT
module. Legacy Deployment/Service/account resources are forgotten without deletion.

Chained moved blocks transfer Microsoft Graph state from the old web registration
through the intermediate SPA address to the Web registration. Never delete the
shared tenant Graph service principal. Review a caller plan for duplicate ownership
before any explicitly approved apply. Old app-specific registrations/proxy/routes
are replaced; temporary authentication downtime is expected during this cutover.

Rollout: publish module, update caller pin/inputs, review plan, obtain apply approval,
provision, then deploy both app MRs. No Terraform apply is part of this change.
