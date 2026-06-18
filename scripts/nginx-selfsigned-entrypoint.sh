#!/bin/sh
# Self-signed nginx entrypoint.
# Generates a 10-year self-signed certificate on first run if missing,
# generates htpasswd from DASHBOARD_USER/DASHBOARD_PASSWORD,
# renders the nginx config template with envsubst, then starts nginx.
#
# Cert is persisted on the shared volume: certbot/conf/live/hermes.local/
# Subsequent container restarts find the existing cert and skip generation.
#
# Variables (set in docker-compose.selfsigned.yml environment):
#   ${ACCESS_KEY_SECRET}   -- shared secret for X-Access-Key header
#   ${DASHBOARD_USER}      -- username for basic auth (default: admin)
#   ${DASHBOARD_PASSWORD}  -- password for basic auth (required)

set -e

CERT_DIR="/etc/letsencrypt/live/hermes.local"
CERT_FILE="$CERT_DIR/fullchain.pem"
KEY_FILE="$CERT_DIR/privkey.pem"
TEMPLATE="/etc/nginx/conf.d/selfsigned.conf.template"
CONF_FILE="/etc/nginx/conf.d/default.conf"
HTPASSWD_FILE="/etc/nginx/.htpasswd"

# Ensure openssl and apache2-utils are available
if ! command -v openssl >/dev/null 2>&1; then
    echo "=== Installing openssl ==="
    apk add --no-cache openssl
fi

if ! command -v htpasswd >/dev/null 2>&1; then
    echo "=== Installing apache2-utils (for htpasswd) ==="
    apk add --no-cache apache2-utils
fi

# Generate htpasswd
echo "=== Generating htpasswd ==="
if [ -n "$DASHBOARD_PASSWORD" ]; then
    USER="${DASHBOARD_USER:-admin}"
    htpasswd -bc "$HTPASSWD_FILE" "$USER" "$DASHBOARD_PASSWORD"
    echo "=== htpasswd created for user: $USER ==="
else
    echo "=== WARNING: DASHBOARD_PASSWORD not set -- basic auth disabled ==="
    touch "$HTPASSWD_FILE"
fi

# Generate self-signed certificate
if [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; then
    echo "=== Generating self-signed certificate (first run) ==="
    mkdir -p "$CERT_DIR"

    openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
        -keyout "$KEY_FILE" \
        -out "$CERT_FILE" \
        -subj "/C=US/ST=Local/L=Local/O=Hermes/CN=hermes.local" \
        -addext "subjectAltName=DNS:hermes.local,DNS:localhost,IP:127.0.0.1"

    echo "=== Certificate generated (valid 10 years) ==="
else
    echo "=== Certificate already exists, skipping generation ==="
fi

# Render nginx config
echo "=== Rendering nginx config ==="
envsubst '${ACCESS_KEY_SECRET}' < "$TEMPLATE" > "$CONF_FILE"

# Start nginx
echo "=== Starting nginx ==="
exec nginx -g 'daemon off;'
