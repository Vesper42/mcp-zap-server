# Security Policy

## Supported Versions

| Version    | Supported |
| ---------- | --------- |
| `>= 0.3.0` | ✅ Active |

## Security Features

### Authentication

- **API Key Authentication**: Bearer token authentication
- **Header**: Use `Authorization: Bearer <api-key>` for all requests
- **Configurable**: Enable/disable via `MCP_SECURITY_MODE` environment variable

### URL Validation

- **Whitelist/Blacklist**: Control which domains can be scanned
- **Private Network Protection**: Blocks internal networks by default
- **Localhost Protection**: Blocks localhost unless explicitly enabled

### Resource Limits

- **Scan Timeouts**: Configurable duration limits
- **Concurrent Scan Limits**: Prevents resource exhaustion
- **Thread Limits**: Configurable threading

## Security Best Practices

### For Deployment

1. **Use strong API keys**:
   ```bash
   openssl rand -hex 32
   ```

2. **Never commit `.env` files** to version control

3. **Configure URL whitelist** for production:
   ```bash
   ZAP_URL_WHITELIST=yourdomain.com,*.yourdomain.com
   ```

4. **Disable localhost scanning** in production:
   ```bash
   ZAP_ALLOW_LOCALHOST=false
   ZAP_ALLOW_PRIVATE_NETWORKS=false
   ```

5. **Set scan limits**:
   ```bash
   ZAP_MAX_ACTIVE_SCAN_DURATION=30
   ZAP_MAX_CONCURRENT_ACTIVE_SCANS=3
   ```

## CSRF Protection

CSRF protection is **disabled by design** because:

1. This is an **API-only server** (no browser-based web UI)
2. Authentication uses **API keys in HTTP headers**, not cookies
3. CSRF attacks only affect **cookie-based authentication**
4. Follows [OWASP guidelines](https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html) for stateless APIs

## Reporting Vulnerabilities

Please report security vulnerabilities by opening an issue or contacting the maintainers directly.
