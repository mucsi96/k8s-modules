# Ingress Controller with Cloudflare Tunnel

This module sets up Traefik as an ingress controller and exposes it to the public internet using Cloudflare tunnels.

## Features

- Deploys Traefik using the official Helm chart
- Creates a dedicated "cloudflare" namespace for Cloudflare resources
- Deploys cloudflared using the official Cloudflare Helm chart
- Configures Cloudflare tunnel to expose Traefik services
- Stores all sensitive credentials in Azure Key Vault
- Creates wildcard DNS records for the domain
- Runs cloudflared with high availability (2 replicas)

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

3. **Get Your Account ID**
   - In the Cloudflare dashboard, go to the right sidebar and scroll down
   - Your Account ID will be listed there
   - Copy this value for later use

4. **Get Your Zone ID**
   - In the Cloudflare dashboard, select your domain
   - Go to the Overview tab
   - Your Zone ID will be displayed on the right side
   - Copy this value for later use

5. **Create API Token**
   - In the Cloudflare dashboard, go to "My Profile" → "API Tokens"
   - Click "Create Token"
   - Use the "Custom token" template
   - Configure the token with the following permissions:
     - Zone:Zone:Read
     - Zone:DNS:Edit
   - Set "Zone Resources" to "Include" → "Specific zone" → select your domain
   - Click "Continue to summary" and then "Create Token"
   - Copy the token value immediately as it won't be shown again

6. **Store Secrets in Azure Key Vault**
   After completing the steps above, store these values in Azure Key Vault:
   - `cloudflare-zone-id` - Your Zone ID from step 4
   - `cloudflare-account-id` - Your Account ID from step 3
   - `cloudflare-api-token` - The API token you just created
   - `dns-zone` - Your domain name (e.g., example.com)
   - `letsencrypt-email` - Email address for Let's Encrypt certificates
