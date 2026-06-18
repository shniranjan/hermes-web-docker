# Hermes Web Docker

> Docker Compose deployment for Hermes Agent with HTTPS reverse proxy.

## Purpose

Single-command Docker deployment of Hermes Agent behind nginx with HTTPS. Two stacks: production (Let's Encrypt) and local (self-signed cert).

## Repository

- **GitHub:** `git@github.com:shniranjan/hermes-web-docker.git`
- **HTTPS:** `https://github.com/shniranjan/hermes-web-docker.git`
- **Local:** `/opt/data/workspace/hermes-web-docker/`

## Key Files

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Production stack (Let's Encrypt SSL) |
| `docker-compose.selfsigned.yml` | Local/dev stack (self-signed cert) |
| `docker-compose.local.yml` | Local stack variant |
| `Dockerfile.slim` | Custom Hermes image |
| `nginx/selfsigned.conf.template` | Nginx config for self-signed |
| `scripts/nginx-selfsigned-entrypoint.sh` | Entrypoint for cert generation |
| `certbot/` | Let's Encrypt automation |

## Host Details

- **Production host:** Separate dedicated machine
- **Image:** `ghcr.io/shniranjan/hermes-agent`

## Goals

- Zero-step workflows: `docker compose up -d` as the only step
- No manual pre-flight scripts or init steps
- HTTPS is mandatory (no plain HTTP)

## Conventions

- Present config reviews as tables: Setting | Current | Issue | Recommendation
- Flag cross-file inconsistencies (compose says X but nginx says Y)
- Organize findings by severity: critical → high → medium → low
- Plan before execution
