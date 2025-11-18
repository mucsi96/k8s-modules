# Cloudflare Rate Limiting Configuration

This module includes comprehensive rate limiting configuration using Cloudflare's WAF-based rate limiting rules.

## Features

The rate limiting configuration includes the following protections:

### 1. API Endpoint Rate Limiting
- **Path**: `/api/*`
- **Limit**: 100 requests per 60 seconds per IP
- **Timeout**: 600 seconds (10 minutes)
- **Action**: Block with 429 status code
- **Characteristics**: IP address + Cloudflare colo ID

### 2. General Traffic Rate Limiting
- **Path**: All paths except `/health` and `/favicon.ico`
- **Limit**: 300 requests per 60 seconds per IP
- **Timeout**: 300 seconds (5 minutes)
- **Action**: Block with 429 status code
- **Characteristics**: IP address

### 3. Authentication Endpoint Rate Limiting
- **Path**: `/auth` and `/login` endpoints
- **Limit**: 10 requests per 300 seconds (5 minutes) per IP
- **Timeout**: 1800 seconds (30 minutes)
- **Action**: Block with 429 status code
- **Purpose**: Prevent brute-force attacks on authentication

### 4. Geographic-Based Rate Limiting (Optional)
- **Enabled**: Set `enable_geo_based_rate_limiting = true` in module configuration
- **Target**: Requests from countries outside US, GB, CA, AU, DE, FR
- **Limit**: 50 requests per 60 seconds per IP
- **Timeout**: 600 seconds (10 minutes)
- **Action**: Managed challenge (CAPTCHA)
- **Purpose**: Additional protection for high-risk regions

## Configuration

### Enable/Disable Geographic Rate Limiting

In your main Terraform configuration (`main.tf`), set the `enable_geo_based_rate_limiting` variable:

```hcl
module "setup_ingress_controller" {
  source                         = "./modules/setup_ingress_controller"
  # ... other variables ...
  enable_geo_based_rate_limiting = true  # Set to false to disable
}
```

### Customizing Rate Limits

To customize rate limits, edit `cloudflare_rate_limiting.tf` and modify:

- `period`: Time window in seconds
- `requests_per_period`: Maximum number of requests allowed in the period
- `mitigation_timeout`: How long to block/challenge after rate limit is exceeded
- `expression`: Cloudflare Rules Language expression to match requests

## How It Works

1. **Request Matching**: Each incoming request is evaluated against the configured expressions
2. **Rate Tracking**: Cloudflare tracks requests based on the specified characteristics (IP, colo ID, etc.)
3. **Limit Enforcement**: When limits are exceeded, the specified action is taken (block or challenge)
4. **Timeout**: After the mitigation timeout expires, the rate limit counter resets

## Testing Rate Limits

You can test rate limits using tools like `curl` or `ab` (Apache Bench):

```bash
# Test API rate limiting (should trigger after 100 requests in 60 seconds)
for i in {1..150}; do curl -s -o /dev/null -w "%{http_code}\n" https://your-domain.com/api/test; done

# Test authentication rate limiting (should trigger after 10 requests in 5 minutes)
for i in {1..15}; do curl -s -o /dev/null -w "%{http_code}\n" https://your-domain.com/auth; sleep 1; done
```

Expected responses:
- `200` - Request allowed
- `429` - Rate limit exceeded

## Monitoring

Monitor rate limiting in the Cloudflare Dashboard:
1. Go to **Security** > **WAF**
2. Click on **Rate limiting rules**
3. View metrics and triggered events

## Best Practices

1. **Start Conservative**: Begin with higher limits and adjust based on actual traffic patterns
2. **Monitor Metrics**: Regularly check Cloudflare analytics to avoid false positives
3. **Whitelist Trusted IPs**: Consider adding firewall rules to whitelist known good IPs
4. **Test Before Production**: Test rate limits in a staging environment first
5. **Document Changes**: Keep track of rate limit adjustments and their reasoning

## Outputs

The module exports:
- `rate_limiting_ruleset_id`: The ID of the rate limiting ruleset for reference

## References

- [Cloudflare Rate Limiting Documentation](https://developers.cloudflare.com/waf/rate-limiting-rules/)
- [Cloudflare Rules Language](https://developers.cloudflare.com/ruleset-engine/rules-language/)
- [Terraform Cloudflare Provider](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs)
