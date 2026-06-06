#!/bin/sh
# Self-signed nginx entrypoint.
# Generates a 10-year self-signed certificate on first run if missing,
# then starts nginx.
#
# Cert is persisted on the shared volume: certbot/conf/live/hermes.local/
# Subsequent container restarts find the existing cert and skip generation.

set -e

CERT_DIR="/etc/letsencrypt/live/hermes.local"
CERT_FILE="$CERT_DIR/fullchain.pem"
KEY_FILE="$CERT_DIR/privkey.pem"

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

echo "=== Starting nginx ==="
exec nginx -g 'daemon off;'
