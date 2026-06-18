#!/bin/sh
# Local dev nginx entrypoint -- no SSL, basic auth only.
# Generates htpasswd from DASHBOARD_USER/DASHBOARD_PASSWORD,
# renders the nginx config, then starts nginx.
#
# Variables (set in docker-compose.local.yml environment):
#   ${DASHBOARD_USER}      -- username for basic auth (default: admin)
#   ${DASHBOARD_PASSWORD}  -- password for basic auth (required)

set -e

TEMPLATE="/etc/nginx/conf.d/local.conf.template"
CONF_FILE="/etc/nginx/conf.d/default.conf"
HTPASSWD_FILE="/etc/nginx/.htpasswd"

# Ensure apache2-utils is available
if ! command -v htpasswd >/dev/null 2>&1; then
    echo "=== Installing apache2-utils (for htpasswd) ==="
    apk add --no-cache apache2-utils
fi

# Generate htpasswd
echo "=== Generating htpasswd ==="
USER="${DASHBOARD_USER:-admin}"
htpasswd -bc "$HTPASSWD_FILE" "$USER" "$DASHBOARD_PASSWORD"
echo "=== htpasswd created for user: $USER ==="

# Render nginx config (no substitutions needed for local)
echo "=== Rendering nginx config ==="
cp "$TEMPLATE" "$CONF_FILE"

# Start nginx
echo "=== Starting nginx on port 80 ==="
echo "=== Access dashboard at http://localhost (user: $USER) ==="
exec nginx -g 'daemon off;'
