#!/bin/sh
# Production nginx entrypoint.
#
# On startup:
#   - Generate htpasswd from DASHBOARD_USER/DASHBOARD_PASSWORD
#   - If TLS cert exists -> start with full SSL prod config immediately
#   - If no cert -> start with bootstrap config (HTTP, ACME passthrough),
#     then poll for the cert file to appear. Once found, swap to prod
#     config and reload.
#
# SIGHUP is trapped for cert renewals -- certbot signals nginx after
# renewing, and we reload to pick up the updated certificate.
#
# Variables (set in docker-compose.nginx.yml environment):
#   ${DOMAIN}              -- your domain (e.g. hermes.example.com)
#   ${ACCESS_KEY_SECRET}   -- shared secret for X-Access-Key header
#   ${DASHBOARD_USER}      -- username for basic auth (default: admin)
#   ${DASHBOARD_PASSWORD}  -- password for basic auth (required)

set -e

DOMAIN="${DOMAIN:?DOMAIN must be set}"
CERT_FILE="/etc/letsencrypt/live/${DOMAIN}/fullchain.pem"
KEY_FILE="/etc/letsencrypt/live/${DOMAIN}/privkey.pem"
BOOTSTRAP_TEMPLATE="/etc/nginx/conf.d/bootstrap.conf.template"
PROD_TEMPLATE="/etc/nginx/conf.d/prod.conf.template"
CONF_FILE="/etc/nginx/conf.d/default.conf"
PID_FILE="/var/run/nginx.pid"
HTPASSWD_FILE="/etc/nginx/.htpasswd"

# Ensure apache2-utils is available
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

# Render helpers
render_bootstrap() {
    echo "=== Rendering bootstrap config ==="
    envsubst '${DOMAIN}' < "$BOOTSTRAP_TEMPLATE" > "$CONF_FILE"
}

render_prod() {
    echo "=== Rendering production SSL config ==="
    envsubst '${DOMAIN} ${ACCESS_KEY_SECRET}' < "$PROD_TEMPLATE" > "$CONF_FILE"
}

reload_nginx() {
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "=== Reloading nginx ==="
        nginx -s reload
    fi
}

# SIGHUP handler (for cert renewals)
on_hup() {
    echo "=== Received SIGHUP (cert renewal) ==="
    reload_nginx
}
trap on_hup HUP

# Startup
if [ -f "$CERT_FILE" ] && [ -f "$KEY_FILE" ]; then
    echo "=== Certificate found at $CERT_FILE -- starting with production SSL ==="
    render_prod
else
    echo "=== No certificate yet -- starting with bootstrap config ==="
    render_bootstrap
fi

echo "=== Starting nginx ==="
nginx -g 'daemon off;' &
NGINX_PID=$!

# Bootstrap to Prod transition (only if started without cert)
if [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; then
    echo "=== Polling for certificate at $CERT_FILE ==="
    for i in $(seq 1 60); do
        if [ -f "$CERT_FILE" ] && [ -f "$KEY_FILE" ]; then
            echo "=== Certificate appeared after ${i}s -- switching to production SSL ==="
            render_prod
            reload_nginx
            echo "=== Production SSL is live! Access your dashboard at https://$DOMAIN ==="
            break
        fi
        if [ "$i" -eq 60 ]; then
            echo "=== WARNING: Certificate did not appear within 120 seconds. Staying on bootstrap config. ==="
            echo "=== Check certbot logs: docker compose logs certbot ==="
        fi
        sleep 2
    done
fi

# Wait for nginx
wait $NGINX_PID
