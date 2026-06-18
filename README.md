# Hermes Agent — Docker Deployment

Standalone Docker deployment of [Hermes Agent](https://github.com/NousResearch/hermes-agent) with Nginx reverse proxy, Let's Encrypt SSL, and the complete web dashboard.

> [!CAUTION]
> ## SECURITY WARNING — READ BEFORE DEPLOYING
>
> **The Hermes web dashboard gives anyone who can reach it FULL CONTROL of the host machine.** Through the dashboard, an attacker can:
> - Run arbitrary shell commands on your server
> - Read, write, and delete files
> - Access your API keys and environment variables
> - Exfiltrate data or pivot to other systems on your network
>
> **This is not a hypothetical risk.** The dashboard is a remote shell with a chat interface. Without authentication, anyone on your network — or the internet, if exposed — can issue commands as the user running the container.
>
> **The `local` stack has NO authentication at all.** Do not use it on any network where other people or devices are present. Even the `selfsigned` and `production` stacks currently expose the backend port directly, bypassing nginx authentication. These are known issues being addressed.
>
> **Minimum precautions:**
> - Never expose any stack to the public internet without authentication
> - Use a firewall to restrict access to trusted IPs only
> - Prefer the self-signed or production stack with `ACCESS_KEY_SECRET` set
> - Verify that port 9119 is NOT reachable from outside the Docker network
> - Consider running behind a VPN (WireGuard, Tailscale) rather than exposing ports
>
> **You are solely responsible for securing your deployment.** The authors assume no liability for unauthorized access, data loss, or system compromise resulting from use of this software.

## Credits

This project is a Docker wrapper and deployment configuration for **[NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent)**, an open-source AI agent framework by [Nous Research](https://nousresearch.com). All agent logic, web dashboard, gateway integrations, MCP support, and more are entirely their work. This repo provides production-ready Docker Compose stacks to make self-hosting painless.

> [!WARNING]
> **Disclaimer:** This is an unofficial community deployment template and is **not affiliated with, endorsed by, or maintained by Nous Research.** Use at your own risk. You are responsible for securing your deployment, protecting your API keys, and complying with the terms of service of any LLM providers you use. The self-signed certificate stack is intended for local/LAN use only — do not expose it to the public internet. Never commit your `.env` file or API keys to version control.

## What Makes This Different

- **Zero pre-flight scripts.** No `./init-ssl.sh` or `./init-selfsigned.sh`. Everything happens inside the containers on `docker compose up -d`. The nginx and certbot containers generate or obtain certificates on first run, then persist them on shared volumes for subsequent restarts.
- **Password-based auth out of the box.** All stacks require authentication. Set `DASHBOARD_PASSWORD` in `.env` and nginx handles the rest — the browser prompts for credentials automatically. No browser extensions needed. An optional `X-Access-Key` cookie mechanism is also available for API/programmatic access.
- **Three stacks, pick your level.** Local dev with no SSL, self-signed HTTPS for LAN, or full Let's Encrypt for production. All use the same Hermes image.

## Quick Start — Pick Your Stack

| Stack | Compose File | SSL | Domain | Auth | When to use |
|---|---|---|---|---|---|---|
| **Local** | `docker-compose.local.yml` | ❌ | ❌ | ✅ basic auth | Isolated dev / localhost only |
| **Self-signed** | `docker-compose.selfsigned.yml` | ✅ self-signed | ❌ | ✅ basic auth | LAN access with HTTPS |
| **Production** | `docker-compose.yml` + nginx | ✅ Let's Encrypt | ✅ required | ✅ basic auth | Internet-facing deployment |

### Local (no SSL, basic auth)

> [!WARNING]
> This stack has no SSL/TLS. The password is sent in cleartext over the network. Only use on localhost or a fully isolated trusted network.

```bash
cp .env.example .env
# Edit .env — set DASHBOARD_PASSWORD + at least one API key
nano .env

docker compose -f docker-compose.local.yml up -d
# Open http://localhost (browser will prompt for username/password)
```

### Self-Signed HTTPS (local / LAN)

```bash
cp .env.example .env
# Edit .env — set DASHBOARD_PASSWORD, ACCESS_KEY_SECRET (optional), + API keys
nano .env

docker compose -f docker-compose.selfsigned.yml up -d
# Open https://localhost (accept the security warning, log in with password)
```

The certificate is generated automatically on first run. Access is protected by basic auth (password) and optionally the X-Access-Key cookie mechanism.

### Production (Let's Encrypt + Domain)

**Prerequisites:** Your domain DNS must point to this server. Ports 80 and 443 must be reachable.

```bash
cp .env.example .env
# Edit .env — set DOMAIN, ACCESS_KEY_SECRET, and at least one API key
nano .env

docker compose up -d
```

That's it. On first run:
1. Nginx starts with a bootstrap config (HTTP only, ACME challenge passthrough)
2. Certbot obtains a Let's Encrypt certificate via webroot mode
3. Nginx is automatically reloaded with full SSL config

Renewals happen automatically every 12 hours in the background.

## Access Security

Two authentication methods are supported, both at the nginx level:

### 1. Basic Auth (primary, recommended)

Set `DASHBOARD_USER` and `DASHBOARD_PASSWORD` in `.env`. Your browser will prompt for credentials on first access. Works with all browsers, no extensions needed.

### 2. X-Access-Key / Cookie (alternative)

The production and self-signed stacks also support cookie-based auth via a shared secret:

```
1. Browser loads https://domain.com  →  sends X-Access-Key: your-secret
2. Nginx validates the key            →  sets hermes_auth=1 cookie
3. Dashboard opens WebSocket/SSE      →  browser auto-attaches cookie
4. Nginx checks cookie                →  allows WebSocket connection
```

This avoids the "WebSocket can't send custom headers" problem. The cookie is `HttpOnly`, `Secure`, `SameSite=Strict`, and expires after 24 hours (requiring re-auth with the actual key).

### How to send the X-Access-Key

The dashboard itself doesn't know about the access key — you need to inject it on the initial request:

| Method | How |
|---|---|
| **Browser extension** | [ModHeader](https://modheader.com/) or similar — add `X-Access-Key` header with your secret |
| **curl** | `curl -H "X-Access-Key: your-secret" https://your-domain.com` |
| **Reverse proxy** | If you sit behind another proxy, add the header there |
| **Bookmarklet** | Inject via a JavaScript bookmarklet that sets the header on load |

Once authenticated, the cookie takes over for the session. No header needed on subsequent requests or WebSocket connections.

## Environment Variables (.env)

Copy `.env.example` to `.env` and fill in:

| Variable | Stack | Required? | Description |
|---|---|---|---|---|
| `ANTHROPIC_API_KEY` | All | Recommended | Anthropic API key |
| `OPENAI_API_KEY` | All | Recommended | OpenAI API key |
| `DEEPSEEK_API_KEY` | All | Recommended | DeepSeek API key |
| `DASHBOARD_USER` | All | No | Username for basic auth (default: `admin`) |
| `DASHBOARD_PASSWORD` | All | **Yes** | Password for dashboard basic auth |
| `DOMAIN` | Production | **Yes** | Your domain (e.g. `hermes.example.com`) |
| `ACCESS_KEY_SECRET` | Production, Self-signed | No | Alternative: shared secret for cookie auth |
| `EMAIL` | Production | No | Email for Let's Encrypt notifications |
| `HERMES_UID` | All | No | UID inside container (default: 1000) |
| `HERMES_GID` | All | No | GID inside container (default: 1000) |
| `HERMES_DASHBOARD_INSECURE` | All | No | Set to 1 to disable auth (NOT recommended) |

## Architecture

```
                 Port 443 (HTTPS)                                       Port 80 (ACME)
                      │                                                      │
                 ┌────▼─────┐                                          ┌─────▼──────┐
                 │  Nginx   │◄── reload after cert obtained ──────────│  Certbot   │
                 │  :443    │                                          │  auto-renew│
                 └────┬─────┘                                          └────────────┘
                      │
                 Port 9119
                      │
                 ┌────▼─────┐     ┌──────────────┐
                 │  Hermes  │────▶│  LLM APIs     │
                 │  :9119   │     │  (Anthropic,  │
                 └──────────┘     │   OpenAI,     │
                                  │   DeepSeek)   │
                                  └──────────────┘
```

## File Structure

```
├── docker-compose.yml              # Production: Hermes (nginx stack separate)
├── docker-compose.selfsigned.yml   # Local HTTPS with self-signed cert
├── docker-compose.local.yml        # Local HTTP with basic auth
├── docker-compose.nginx.yml        # Production nginx + Certbot stack
├── .env.example                    # All supported environment variables
├── nginx/
│   ├── prod-bootstrap.conf.template # Bootstrap config (pre-SSL, ACME passthrough)
│   ├── prod.conf.template          # Full production SSL config
│   ├── selfsigned.conf.template    # Self-signed HTTPS config
│   └── local.conf.template         # Local HTTP config (basic auth only)
├── scripts/
│   ├── certbot-entrypoint.sh       # Initial cert + renewal loop
│   ├── nginx-prod-entrypoint.sh    # Prod SSL + htpasswd generation
│   ├── nginx-selfsigned-entrypoint.sh  # Self-signed cert + htpasswd generation
│   └── nginx-local-entrypoint.sh   # Local htpasswd generation
├── Dockerfile.slim                 # Slim image build
└── certbot/                        # Shared volume (certs + ACME challenges)
    ├── www/                        # ACME challenge webroot
    └── conf/                       # Let's Encrypt certs
```

## Image Variants

Two images published to [GHCR](https://github.com/shniranjan/hermes-web-docker/pkgs/container/hermes-agent):

| Tag | Description | Best For |
|---|---|---|
| `:latest`, `:slim` | Slim runtime (~1.5–2 GB) | Dashboard, text chat, most adapters |
| `:full` | Complete image (~2–3 GB) | Playwright browsing, ffmpeg, git, voice processing |

**To switch to the full image**, change the image tag in your compose file to `:full`.

### Building Your Own Image

```bash
# Build the slim image (default)
docker build -f Dockerfile.slim -t hermes-agent:local .

# Then reference it in docker-compose.yml:
#   image: hermes-agent:local
```

## Managing the Stack

```bash
# View logs
docker compose logs -f hermes
docker compose logs -f certbot

# Access the Hermes CLI
docker compose exec hermes /opt/hermes/.venv/bin/hermes status

# Restart
docker compose restart

# Stop everything
docker compose down

# Use a different compose file
docker compose -f docker-compose.selfsigned.yml logs -f nginx
```

## Security

### Authentication

All three stacks now require authentication:

| Stack | Auth method | Password sent |
|---|---|---|
| **Local** | Basic auth (HTTP) | Cleartext — localhost only |
| **Self-signed** | Basic auth + optional X-Access-Key cookie | Encrypted (HTTPS) |
| **Production** | Basic auth + optional X-Access-Key cookie | Encrypted (HTTPS) |

Set `DASHBOARD_USER` and `DASHBOARD_PASSWORD` in `.env`. On `docker compose up`, the nginx entrypoint generates an htpasswd file automatically. The browser will prompt for username/password on first access.

The `ACCESS_KEY_SECRET` cookie-based mechanism is still available as an alternative (useful for API access or browser extensions). With `satisfy any`, either basic auth OR the access key grants entry.

Hermes itself is no longer directly exposed on any host port — all traffic must go through nginx.

## Troubleshooting

**Q: Dashboard shows "Gateway not connected"**
Check: `docker compose exec hermes /opt/hermes/.venv/bin/hermes gateway status`
The gateway starts inside the container — verify `HERMES_GATEWAY_BOOTSTRAP_STATE=running` is set.

**Q: SSL certificate won't issue**
- DNS must point to this server and propagate
- Port 80 must be open to the internet
- Check logs: `docker compose logs certbot`
- Make sure `DOMAIN` is set correctly in `.env`

**Q: Cookie auth not working / 401 on WebSocket**
- First, ensure you're logged in via basic auth (browser password prompt)
- If using X-Access-Key instead: make sure you access the dashboard via HTTPS (the cookie is `Secure`)
- Clear cookies and re-authenticate with the `X-Access-Key` header
- Check `ACCESS_KEY_SECRET` in `.env` matches what you're sending

**Q: Forgot dashboard password**
Check `DASHBOARD_PASSWORD` in `.env`. To change it, update the value and restart the nginx container:
```bash
docker compose restart nginx
```

**Q: Permission errors**
Set correct UID/GID:
```bash
HERMES_UID=$(id -u) HERMES_GID=$(id -g) docker compose up -d
```

**Q: Browser won't connect to self-signed stack**
- The certificate is self-signed — click **Advanced → Proceed to localhost (unsafe)**
- Chrome: type `thisisunsafe` on the warning page
- Firefox: click **Advanced → Accept the Risk and Continue**
- If you changed the host or regenerated the cert, delete the old one:
  ```bash
  rm -rf certbot/conf
  docker compose -f docker-compose.selfsigned.yml restart nginx
  ```
