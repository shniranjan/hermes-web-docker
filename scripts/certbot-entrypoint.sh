#!/bin/sh
# Production certbot entrypoint.
#
# Phase 1 — Initial certificate (first run only):
#   Uses certbot in webroot mode — nginx is already running with the
#   bootstrap config and serving ACME challenges from /var/www/certbot.
#   Once the cert is obtained, rewrites the nginx config to the full
#   SSL version and reloads nginx.
#
# Phase 2 — Renewal loop (always):
#   Checks twice daily and auto-renews when within 30 days of expiry.
#   Renewals don't need port 80 — certbot uses the webroot again.

set -e

DOMAIN="${DOMAIN:?DOMAIN must be set in .env}"
EMAIL="${EMAIL:-admin@$DOMAIN}"

CERT_DIR="/etc/letsencrypt/live/$DOMAIN"
CERT_FILE="$CERT_DIR/fullchain.pem"

echo "=== Certbot entrypoint starting for $DOMAIN ==="

# ── Phase 1: Initial certificate ──────────────────────────────────────
if [ ! -f "$CERT_FILE" ]; then
    echo "=== No certificate found. Requesting initial Let's Encrypt certificate ==="

    # nginx should already be running with the bootstrap config.
    # Wait for nginx to be ready.
    echo "Waiting for nginx to be ready on port 80..."
    for i in $(seq 1 30); do
        if wget -q -O /dev/null http://localhost/.well-known/acme-challenge/ 2>/dev/null \
           || curl -s -o /dev/null http://localhost/.well-known/acme-challenge/ 2>/dev/null; then
            echo "nginx is ready (HTTP 200 on ACME endpoint)"
            break
        fi
        if [ "$i" -eq 30 ]; then
            echo "ERROR: nginx did not become ready within 30 seconds"
            exit 1
        fi
        sleep 2
    done

    certbot certonly --webroot \
        --webroot-path /var/www/certbot \
        --email "$EMAIL" \
        --agree-tos \
        --no-eff-email \
        --force-renewal \
        -d "$DOMAIN"

    echo "=== Certificate obtained! ==="

    # Swap nginx to the full SSL config.
    echo "=== Switching nginx to production SSL config ==="
    envsubst '${DOMAIN} ${ACCESS_KEY_SECRET}' \
        < /etc/nginx/conf.d/prod.conf.template \
        > /etc/nginx/conf.d/default.conf

    echo "=== Reloading nginx ==="
    nginx -s reload

    echo "=== Production SSL is live! Access your dashboard at https://$DOMAIN ==="
else
    echo "=== Certificate already exists at $CERT_FILE ==="
fi

# ── Phase 2: Renewal loop ─────────────────────────────────────────────
echo "=== Starting renewal loop (checks every 12h) ==="
while :; do
    certbot renew --quiet --webroot --webroot-path /var/www/certbot
    nginx -s reload 2>/dev/null || true
    sleep 12h
done
