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
`setup_app_forwardauth`. Hello always uses this Web registration and requires
ForwardAuth configuration. Cooking selects it when ForwardAuth is configured,
with `register_spa` available for its legacy browser-OAuth mode.
