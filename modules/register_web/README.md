# register_web

Registers a confidential Entra **Web** client for server-side authorization-code
flows such as oauth2-proxy ForwardAuth. It creates Web callbacks, a persisted
client credential, OIDC consent, required app assignment and owner/additional-user
assignments. Implicit grants are disabled. There is no SPA redirect configuration.

```hcl
module "web_client" {
  source = "../register_web"

  display_name  = "Hello Web"
  owner         = var.owner
  redirect_uris = ["https://${var.hostname}/oauth2/callback"]
  api_access = {
    application_id = module.api.application_id
    client_id      = module.api.client_id
    scope_id       = module.api.scope_id
  }
}
```

`api_access` is optional: omit it for email-header/login-gate services without an
API registration. The module requests `openid profile email offline_access`, not
Graph `User.Read`. API preauthorization, when configured, uses only the supplied
API scope. API role assignments remain owned by the API/application modules.

The two outputs, `client_id` and sensitive `client_secret`, are consumed by
`setup_app_forwardauth`. Hello/Cooking select this module whenever `forward_auth`
is configured; `register_spa` is used only by their legacy browser-OAuth mode.

## Existing registration migration

The Web-only client must be adopted in Terraform state rather than recreated.
Hello/Cooking contain a move from their old unindexed SPA module to index zero;
legacy SPA consumers keep their existing registration through that move.
ForwardAuth environments add the corresponding environment-level module move
from that indexed address to the new Web module. See
[the p07 example](p07-migration.tf.example).

The moves in this module then rename the old resource addresses while retaining
the application/service-principal IDs, client ID, password key/value, API
preauthorization, OIDC consent and owner/household assignments. The old
`azuread_application_password.web[0]` becomes the unindexed Web password without
rotation. No production state is copied into module source.

This migration removes any retained SPA redirects in place. Deploy the matching
cookie-auth API/client builds before the Web-only cutover and remove the old
`retain_spa_redirects` input from environment configuration. For p07, Hello is
already deployed; complete Cooking's app MR #29 cutover before upgrading the
environment to this Web-only migration release. Chart 5.0.0 is pinned by the
earlier chart-fix module release, so login can be restored before this cleanup.

A migration plan should keep registrations, passwords, grants and assignments
at their existing IDs. The expected application update removes only obsolete
SPA redirects; changing registration kind requires the corresponding state move.
The legacy SPA-named app outputs and vault secret continue to carry the selected
browser client ID for existing consumers. ForwardAuth uses Web credentials
directly and does not consume the SPA module.
