# Ingress Controller behind the Cloudflare proxy

This module sets up Traefik as an ingress controller and exposes it to the public
internet through the Cloudflare proxy (orange-cloud DNS), with the origin reachable
only from Cloudflare's edge.

Routing uses the Kubernetes **Gateway API** (`Gateway` + `HTTPRoute`), not Traefik's
own `IngressRoute`/`Ingress` providers — both of those are disabled. The Gateway API
CRDs (standard channel) are vendored under `files/` and applied before Traefik starts.

## How traffic flows

1. The wildcard DNS record `*.<dns_zone>` is a **proxied A record** pointing at the
   cluster server's public IPv4.
2. Every request passes the Cloudflare edge, where the zone rulesets are enforced:
   rate limiting, ASN restriction, bot and threat-score blocking
   (`cloudflare_ruleset.tf`).
3. The edge connects to the origin on port 443 (SSL mode **Full (strict)**,
   `always_use_https` on, so port 80 is never used).
4. Traefik binds host port 443 on the `web` entrypoint; the Gateway's HTTPS
   listener terminates TLS with a **Cloudflare Origin CA certificate** (15-year
   validity, no renewal automation needed), referenced from the listener's
   `certificateRefs`.
5. The Hetzner Cloud firewall (`provision_hetzner_server` module) only admits
   Cloudflare's published IP ranges on port 443, so the edge — and its security
   rules — cannot be bypassed by connecting to the server IP directly.

Traefik only honors `X-Forwarded-*` headers from Cloudflare's IP ranges, so apps
and access logs see real client IPs that cannot be spoofed.

## Features

- Deploys Traefik using the official Helm chart, with the Gateway API provider
  enabled and the IngressRoute/Ingress providers disabled
- Installs the Gateway API CRDs and defines the shared `Gateway` (one HTTPS listener)
- Creates the proxied wildcard DNS record and zone SSL settings
- Issues a Cloudflare Origin CA certificate and wires it into the Gateway listener
- Protects the Traefik dashboard with oauth2-proxy (Microsoft Entra ID SSO), routed
  via an `HTTPRoute`

## Prerequisites

### Manual Cloudflare Setup Steps

Before using this module, you need to perform these manual steps in the Cloudflare dashboard:

1. **Sign up for Cloudflare Account**
   - Go to [https://dash.cloudflare.com/sign-up](https://dash.cloudflare.com/sign-up)
   - Create a new account or sign in to an existing one

2. **Add Your Domain to Cloudflare**
   - Click "Add a site" and enter your domain name
   - Select the free plan or appropriate plan for your needs
   - Follow the instructions to update your nameservers at your domain registrar
   - Wait for the nameserver changes to propagate (can take up to 24 hours)

3. **Get Your Zone ID**
   - In the Cloudflare dashboard, select your domain
   - Go to the Overview tab
   - Your Zone ID will be displayed on the right side
   - Copy this value for later use

4. **Create API Token**
   - In the Cloudflare dashboard, go to "My Profile" → "API Tokens"
   - Click "Create Token"
   - Use the "Custom token" template
   - Configure the token with the following permissions:

   | Resource Type | Permission | Access Level | Used for |
   |---------------|------------|--------------|----------|
   | Zone | DNS | Edit | Proxied wildcard A record |
   | Zone | Zone Settings | Edit | SSL mode Full (strict), Always Use HTTPS |
   | Zone | SSL and Certificates | Edit | Origin CA certificate issuance |
   | Account | Account Rulesets | Edit | Rate limiting, ASN restriction, bot blocking rulesets |

   Tokens created for the previous Cloudflare Tunnel setup may still carry
   permissions that are no longer used and can be removed:

   - Account / Cloudflare Tunnel
   - Account / Access: Organizations, Identity Providers, and Groups
   - Account / Access: Apps and Policies

   - Set "Zone Resources" to "Include" → "Specific zone" → select your domain
   - Click "Continue to summary" and then "Create Token"
   - Copy the token value immediately as it won't be shown again

5. **Store Secrets in Azure Key Vault**
   After completing the steps above, store these values in Azure Key Vault:
   - `cloudflare-zone-id` - Your Zone ID from step 3
   - `cloudflare-api-token` - The API token you just created
   - `dns-zone` - Your domain name (e.g., example.com)
