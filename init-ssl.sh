#!/bin/bash
# Initial SSL certificate setup for Hermes Agent
# Run this ONCE to get your Let's Encrypt certificate before starting the stack.
#
# Prerequisites:
#   1. Your domain DNS must point to this server
#   2. Port 80 must be reachable from the internet
#   3. Replace your-domain.com in nginx.conf FIRST

set -e

DOMAIN="your-domain.com"  # <-- CHANGE THIS to your actual domain

# Check if domain is set
if [ "$DOMAIN" = "your-domain.com" ]; then
    echo "ERROR: Please edit this script and set DOMAIN to your actual domain"
    exit 1
fi

echo "Requesting SSL certificate for $DOMAIN..."

# Create directories
mkdir -p certbot/www certbot/conf

# Get the certificate using standalone mode (no running nginx needed)
docker run --rm \
    -v "$(pwd)/certbot/www:/var/www/certbot" \
    -v "$(pwd)/certbot/conf:/etc/letsencrypt" \
    -p 80:80 \
    certbot/certbot:latest \
    certonly --standalone \
    --email admin@$DOMAIN \
    --agree-tos \
    --no-eff-email \
    -d $DOMAIN

echo ""
echo "SSL certificate obtained! Now start the full stack:"
echo "  docker compose up -d"
echo ""
echo "Then open: https://$DOMAIN"
