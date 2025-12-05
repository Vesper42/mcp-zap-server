# MCP ZAP Server

MCP server for OWASP ZAP security scanning - enables AI agents to perform automated web security testing via the Model Context Protocol.

> **Original Project**: This is a simplified fork of [dtkmn/mcp-zap-server](https://github.com/dtkmn/mcp-zap-server)

## Features

- **MCP ZAP Server**: Exposes ZAP actions as MCP tools via Streamable HTTP (JSON-RPC)
- **OpenAPI Integration**: Import remote OpenAPI specs into ZAP and kick off active scans
- **Report Generation**: Generate HTML/JSON reports and fetch contents programmatically
- **Dockerized**: Runs ZAP and the MCP server in containers, orchestrated via docker-compose
- **Secure**: API key authentication for MCP server access

## Architecture

```mermaid
flowchart LR
  subgraph "DOCKER COMPOSE"
    direction LR
    ZAP["OWASP ZAP (port 8091)"]
    MCPZAP["MCP ZAP Server (port 7456)"]
  end

  MCPClient["MCP Client (Claude Desktop, Cursor, etc.)"] <-->|Streamable HTTP JSON-RPC| MCPZAP
  MCPZAP -->|ZAP REST API| ZAP
  ZAP -->|scan, alerts, reports| MCPZAP

  ZAP -->|spider/active-scan| TargetApp["Your Target Application"]
```

## Prerequisites

- Docker ≥ 20.10
- Docker Compose ≥ 1.29
- LLM with Tool calling support (e.g., GPT-4, Claude 3, Llama 3)

## Quick Start

```bash
git clone https://github.com/Vesper42/mcp-zap-server.git
cd mcp-zap-server

# Setup environment variables
cp .env.example .env
# Edit .env with your API keys

# Install and start services
./zap.sh --install
```

**Build time:** ~2-3 minutes  
**Startup:** ~3-5 seconds

### Generate API Keys

```bash
# Generate ZAP API key
openssl rand -hex 32

# Generate MCP API key  
openssl rand -hex 32
```

### Management Commands

```bash
./zap.sh --install     # Install and start services
./zap.sh --status      # Check service status
./zap.sh --logs        # View logs (Ctrl+C to exit)
./zap.sh --restart     # Restart all services
./zap.sh --stop        # Stop services
./zap.sh --uninstall   # Remove containers and images
./zap.sh --help        # Show all commands
```

## Authentication

The MCP server uses API key authentication via `Authorization: Bearer` header:

```bash
# Test MCP endpoint
curl -X POST http://localhost:7456/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "Authorization: Bearer your-mcp-api-key" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}'
```

### Security Modes

| Mode | Description | Use Case |
|------|-------------|----------|
| `api-key` | API key authentication (default) | Recommended for all deployments |
| `none` | No authentication | Development only (⚠️ NOT SECURE) |

Configure in `.env`:
```bash
MCP_SECURITY_MODE=api-key
MCP_API_KEY=your-secure-api-key-here
```

## MCP Client Configuration

### Claude Desktop / Cursor / Windsurf

Add to your MCP client configuration:

```json
{
  "mcpServers": {
    "zap-mcp-server": {
      "protocol": "mcp",
      "transport": "streamable-http",
      "url": "http://localhost:7456/mcp",
      "headers": {
        "Authorization": "Bearer your-mcp-api-key-here"
      }
    }
  }
}
```

## Available Tools

The MCP server exposes 18 ZAP tools:

| Tool | Description |
|------|-------------|
| `zap_spider` | Start a spider scan on a URL |
| `zap_spider_status` | Get spider scan status |
| `zap_ajax_spider` | Start AJAX spider (for JavaScript apps) |
| `zap_ajax_spider_status` | Get AJAX spider status |
| `zap_ajax_spider_stop` | Stop AJAX spider |
| `zap_ajax_spider_results` | Get AJAX spider results |
| `zap_active_scan` | Start an active security scan |
| `zap_active_scan_status` | Get active scan progress |
| `zap_stop_active_scan` | Stop an active scan |
| `zap_stop_all_scans` | Stop all running scans |
| `zap_alerts` | Get security alerts for a URL |
| `zap_urls` | List discovered URLs |
| `zap_hosts` | List discovered hosts |
| `zap_sites` | List discovered sites |
| `zap_import_openapi_spec_url` | Import OpenAPI spec from URL |
| `zap_import_openapi_spec_file` | Import OpenAPI spec from file |
| `zap_view_templates` | List report templates |
| `zap_generate_report` | Generate a security report |

## URL Security

By default, the server blocks scanning of:
- Localhost and loopback addresses
- Private network ranges (10.x, 172.16.x, 192.168.x)
- Link-local addresses

Configure allowed domains in `.env`:
```bash
ZAP_URL_WHITELIST=example.com,*.test.com
```

## Services

| Service | Port | Description |
|---------|------|-------------|
| `mcp-server` | 7456 | MCP server (Streamable HTTP) |
| `zap` | 8091 | OWASP ZAP daemon |

## Endpoints

- **MCP**: `http://localhost:7456/mcp`
- **Health**: `http://localhost:7456/actuator/health`
- **ZAP API**: `http://localhost:8091`

## Prompt Examples

### Spider Scan
```
Spider scan https://example.com and show me the discovered URLs
```

### Active Scan
```
Run an active security scan on https://example.com and generate a report
```

### Import OpenAPI
```
Import the OpenAPI spec from https://api.example.com/openapi.json and scan the API
```

## License

MIT License - See [LICENSE](LICENSE) for details.

## Credits

Forked from [dtkmn/mcp-zap-server](https://github.com/dtkmn/mcp-zap-server)
