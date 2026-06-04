# Hermes Agent - Production Docker Setup

Standalone Docker deployment of [Hermes Agent](https://github.com/NousResearch/hermes-agent) with Nginx reverse proxy,
automatic Let's Encrypt SSL, and the complete web dashboard.

## Credits

This project is a Docker wrapper and deployment configuration for
**[NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent)**,
an open-source AI agent framework developed by [Nous Research](https://nousresearch.com).

All the agent logic, web dashboard, gateway integrations, MCP support, and more
are entirely their work. This repo simply provides a production-ready Docker Compose
stack (Nginx + SSL + Certbot) to make self-hosting easier.

Please star the [upstream repo](https://github.com/NousResearch/hermes-agent)!

## Quick Start (No Local Clone Required)

The Hermes Agent Docker image is **automatically built by GitHub Actions** and published to [GitHub Container Registry](https://github.com/shniranjan/hermes-web-docker/pkgs/container/hermes-agent). No local clone or manual build needed.

### 1. Configure Your Domain

Edit `nginx.conf` — replace `your-domain.com` with your actual domain (3 places).

### 2. Add Your API Keys

Create a `.env` file:

```bash
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...
```

### 3. Get SSL Certificates (first time only)

Edit `init-ssl.sh` and set your domain, then run:

```bash
./init-ssl.sh
```

### 4. Pull the Auto-Built Image and Start

```bash
docker compose pull hermes
docker compose up -d
```

The image is built automatically by GitHub Actions — no need to build locally.

### 5. Open in Browser

Visit **https://your-domain.com**

## Architecture

```
┌──────────────────────────────────────────────────┐
│                   Docker Host                      │
│                                                    │
│  ┌──────────┐   ┌──────────┐   ┌──────────────┐  │
│  │  Nginx   │──▶│  Hermes  │──▶│  LLM APIs     │  │
│  │  :443    │   │  :9119   │   │  (Anthropic,  │  │
│  │  HTTPS   │   │          │   │   OpenAI, etc)  │  │
│  └──────────┘   └──────────┘   └──────────────┘  │
│                                                    │
│  ┌──────────┐                                     │
│  │  Certbot │  (auto-renew every 12h)             │
│  └──────────┘                                     │
└──────────────────────────────────────────────────┘
```

## Services

| Service | Description | Port |
|---------|-------------|------|
| `hermes` | Hermes Agent (gateway + dashboard) | 9119 (internal) |
| `nginx` | Reverse proxy with HTTPS | 80, 443 |
| `certbot` | Automatic Let's Encrypt renewal | - |

## Configuration

### Environment Variables (.env)

| Variable | Description |
|---|---|
| `ANTHROPIC_API_KEY` | Your Anthropic API key |
| `OPENAI_API_KEY` | Your OpenAI API key |
| `HERMES_DASHBOARD_INSECURE` | Set to `1` for local/no-OAuth access |

### Without HTTPS (Local Development)

For local use without a domain, use the simpler `docker-compose.simple.yml`:

```bash
docker compose -f docker-compose.simple.yml up -d
# Open http://localhost:9119
```

## Volume Persistence

Configuration and state are stored in `~/.hermes` on the host. This includes:
- `config.yaml` - Hermes configuration
- `.env` - API keys
- `sessions/` - Chat sessions
- `models/` - Model configurations
- `skills/` - Installed skills

## Managing the Agent

```bash
# View logs
docker compose logs -f hermes

# Access the CLI
docker compose exec hermes hermes status
docker compose exec hermes hermes models list

# Restart
docker compose restart

# Rebuild after changes
docker compose build --no-cache
docker compose up -d
```

## Troubleshooting

**Q: Dashboard shows 'Gateway not connected'**
- Check: `docker compose exec hermes hermes gateway status`
- Restart: `docker compose restart hermes`

**Q: SSL certificate won't issue**
- Ensure port 80 is open and your domain DNS points to this server
- Check: `docker compose logs certbot`

**Q: Permission errors on ~/.hermes**
- Set correct UID/GID: `HERMES_UID=$(id -u) HERMES_GID=$(id -g) docker compose up -d`
