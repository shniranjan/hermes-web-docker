#!/bin/bash
# Generate self-signed SSL certificate for local HTTPS access.
# No domain required — uses "hermes.local" as the Common Name
# with SANs for localhost and 127.0.0.1.
#
# Run this ONCE before starting the selfsigned stack:
#   ./init-selfsigned.sh
#   docker compose -f docker-compose.selfsigned.yml up -d

set -e

CERT_DIR="certbot/conf/live/hermes.local"
DOMAIN="hermes.local"

# Create directories
mkdir -p "$CERT_DIR" certbot/www

# Check if cert already exists
if [ -f "$CERT_DIR/fullchain.pem" ]; then
    echo "Certificate already exists at $CERT_DIR/"
    echo "To regenerate, delete the files first: rm -rf certbot/conf"
    exit 0
fi

echo "Generating self-signed 10-year certificate for $DOMAIN..."

openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout "$CERT_DIR/privkey.pem" \
    -out "$CERT_DIR/fullchain.pem" \
    -subj "/C=US/ST=Local/L=Local/O=Hermes/CN=$DOMAIN" \
    -addext "subjectAltName=DNS:$DOMAIN,DNS:localhost,IP:127.0.0.1"

echo ""
echo "Self-signed certificate generated!"
echo "  Key:  $CERT_DIR/privkey.pem"
echo "  Cert: $CERT_DIR/fullchain.pem"
echo ""
echo "Now start the stack:"
echo "  docker compose -f docker-compose.selfsigned.yml up -d"
echo ""
echo "Then open: https://localhost"
echo ""
echo "Note: Your browser will warn about the self-signed certificate."
echo "Click Advanced → Proceed to localhost (unsafe) to continue."
