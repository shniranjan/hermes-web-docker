# Hermes Agent — Docker Deployment

Standalone Docker deployment of [Hermes Agent](https://github.com/NousResearch/hermes-agent) with HTTPS and authentication.

> [!CAUTION]
> ## SECURITY WARNING — READ BEFORE DEPLOYING
>
> **The Hermes web dashboard gives anyone who can reach it FULL CONTROL of the host machine.** Through the dashboard, an attacker can run arbitrary shell commands, read/write/delete files, access your API keys, and pivot to other systems on your network.
>
> **All stacks now require a password.** Set `DASHBOARD_PASSWORD` in `.env` before deploying. The dashboard is a remote shell with a chat interface — do not expose it without authentication.
>
> **Minimum precautions:**
> - Never expose any stack to the public internet without a strong password
> - Use a firewall to restrict access to trusted IPs
> - Consider running behind a VPN rather than exposing ports
>
> **You are solely responsible for securing your deployment.** The authors assume no liability for unauthorized access, data loss, or system compromise.

## Credits

This project is a Docker wrapper and deployment configuration for **[NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent)**, an open-source AI agent framework by [Nous Research](https://nousresearch.com). All agent logic, web dashboard, gateway integrations, MCP support, and more are entirely their work.

> [!WARNING]
> **Disclaimer:** This is an unofficial community deployment template and is **not affiliated with, endorsed by, or maintained by Nous Research.** Use at your own risk. You are responsible for securing your deployment, protecting your API keys, and complying with the terms of service of any LLM providers you use. Never commit your `.env` file or API keys to version control.

## Quick Start — Pick Your Stack

| Stack | Compose File | SSL | Auth | When to use |
|---|---|---|---|---|
| **Local** | `docker-compose.local.yml` | ❌ | ✅ password | Localhost only |
| **Self-signed** | `docker-compose.selfsigned.yml` | ✅ self-signed | ✅ password | LAN access with HTTPS |
| **Production** | `docker-compose.yml` + nginx stack | ✅ Let's Encrypt | ✅ password | Internet-facing |

### Local (no SSL, password-protected)

> [!WARNING]
> This stack has no SSL/TLS. The password is sent in cleartext over the network. Only use on localhost or a fully isolated trusted network.

```bash
cp .env.example .env
nano .env   # set DASHBOARD_PASSWORD + at least one API key
docker compose -f docker-compose.local.yml up -d
# Open http://localhost
```

### Self-Signed HTTPS (local / LAN)

```bash
cp .env.example .env
nano .env   # set DASHBOARD_PASSWORD + at least one API key
docker compose -f docker-compose.selfsigned.yml up -d
# Open https://localhost (accept the security warning)
```

### Production (Let's Encrypt + Domain)

**Prerequisites:** Your domain DNS must point to this server. Ports 80 and 443 must be reachable.

```bash
cp .env.example .env
nano .env   # set DOMAIN, DASHBOARD_PASSWORD + at least one API key
docker compose up -d
docker compose -f docker-compose.nginx.yml up -d
```

The certificate is obtained automatically on first run and renews in the background.

## Environment Variables

Copy `.env.example` to `.env` and fill in:

| Variable | Required? | Description |
|---|---|---|
| `ANTHROPIC_API_KEY` | Recommended | Anthropic API key |
| `OPENAI_API_KEY` | Recommended | OpenAI API key |
| `DEEPSEEK_API_KEY` | Recommended | DeepSeek API key |
| `DASHBOARD_USER` | No | Username for login (default: `admin`) |
| `DASHBOARD_PASSWORD` | **Yes** | Password for dashboard access |
| `DOMAIN` | Production only | Your domain (e.g. `hermes.example.com`) |
| `EMAIL` | No | Email for Let's Encrypt notifications |
| `HERMES_UID` | No | UID inside container (default: 1000) |
| `HERMES_GID` | No | GID inside container (default: 1000) |

## Image Variants

| Tag | Description | Best For |
|---|---|---|
| `:latest`, `:slim` | Slim runtime (~1.5–2 GB) | Dashboard, text chat |
| `:full` | Complete image (~2–3 GB) | Playwright browsing, ffmpeg, git, voice |

```bash
# Build the slim image
docker build -f Dockerfile.slim -t hermes-agent:local .
```

## Managing the Stack

```bash
docker compose logs -f hermes
docker compose restart
docker compose down
# Use a different compose file
docker compose -f docker-compose.selfsigned.yml logs -f nginx
```

## Troubleshooting

**Q: Dashboard shows "Gateway not connected"**
Check that `HERMES_GATEWAY_BOOTSTRAP_STATE=running` is set in your compose file.

**Q: SSL certificate won't issue**
- DNS must point to this server and propagate
- Port 80 must be open to the internet
- Check logs: `docker compose logs certbot`
- Make sure `DOMAIN` is set correctly in `.env`

**Q: Forgot dashboard password**
Check `DASHBOARD_PASSWORD` in `.env`. Update it and restart:
```bash
docker compose restart nginx
```

**Q: Permission errors**
Set correct UID/GID:
```bash
HERMES_UID=$(id -u) HERMES_GID=$(id -g) docker compose up -d
```

**Q: Browser won't connect to self-signed stack**
- Click **Advanced → Proceed to localhost (unsafe)**
- Chrome: type `thisisunsafe` on the warning page
- Firefox: click **Advanced → Accept the Risk and Continue**
