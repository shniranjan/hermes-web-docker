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

Edit `nginx.conf.template` — replace `your-domain.com` with your actual domain (3 places).

### 2. Add Your API Keys and Access Secret

Create a `.env` file:

```bash
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...

# Generate a random 64-char key: openssl rand -hex 32
ACCESS_KEY_SECRET=your-random-64-char-hex-key-here
```

This `ACCESS_KEY_SECRET` protects your dashboard. Every request must include
an `X-Access-Key` header matching this secret — otherwise Nginx returns 401.
Treat it like an API key. The Hermes web dashboard includes this header
automatically so you're never prompted in the browser.

### 3. Get SSL Certificates (first time only)

Edit `init-ssl.sh` and set your domain, then run:

```bash
./init-ssl.sh
```

### 4. Pull the Auto-Built Image and Start

```bash
# Pull the image first (it's large — ~2-3 GB — this may take a few minutes)
docker compose pull hermes
docker compose up -d
```

The image is built automatically by GitHub Actions — no need to build locally.

### Image Variants

Two images are published to [GHCR](https://github.com/shniranjan/hermes-web-docker/pkgs/container/hermes-agent):

| Tag | Description | Size | Best For |
|---|---|---|---|
| `:latest`, `:slim` | Slim runtime image (default) | ~1.5–2 GB | Dashboard, text chat, most adapters |
| `:full` | Complete upstream image | ~2–3 GB | Full toolkit: Playwright browsing, ffmpeg, git-based skills, voice processing |

The slim image strips build tools (`gcc`, `python3-dev`), Playwright browsers, `ffmpeg`, `git`, and `docker-cli`. Most users should start with `:latest`. If you need web browsing, voice memos, or dynamic skill cloning from git, switch to `:full` by changing the image tag in `docker-compose.yml`.

> **First pull is slow:** The image is large. First pull takes 2–5 minutes depending on your connection. Subsequent pulls are incremental.

### 5. Open in Browser

Visit **https://your-domain.com**

## Architecture

```
┌──────────────────────────────────────────────────┐
│                   Docker Host                                                      │
│                                                                                   │
│  ┌──────────┐     ┌──────────┐     ┌──────────────┐    │
│  │  Nginx          │──▶│  Hermes        │──▶│  LLM APIs              │    │
│  │  :443           │     │  :9119         │     │  (Anthropic,           │    │
│  │  HTTPS          │     │                │     │   OpenAI, etc)         │    │
│  └──────────┘     └──────────┘     └──────────────┘    │
│                                                                                   │
│  ┌──────────┐                                                             │
│  │  Certbot        │  (auto-renew every 12h)                                     │
│  └──────────┘                                                             │
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
| `ACCESS_KEY_SECRET` | Shared secret for Nginx access-key protection (64 chars) |
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
