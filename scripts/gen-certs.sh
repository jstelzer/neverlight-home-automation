#!/bin/bash
# Generate/renew certificates for the mTLS gateway
# Usage: ./gen-certs.sh [provisioner-password]
#
# If no password provided, reads from /etc/neverlight/step-pw (for automated renewal)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CERT_DIR="$SCRIPT_DIR/../certs"
PASSWORD_FILE="/etc/neverlight/step-pw"

# Get password from argument or file
if [ -n "$1" ]; then
  echo "$1" > /tmp/.step-pw
  chmod 600 /tmp/.step-pw
  PW_FILE="/tmp/.step-pw"
  CLEANUP_PW=1
elif [ -f "$PASSWORD_FILE" ]; then
  PW_FILE="$PASSWORD_FILE"
  CLEANUP_PW=0
else
  echo "Usage: $0 <provisioner-password>"
  echo "  Or store password in $PASSWORD_FILE for automated renewal"
  exit 1
fi

# Copy root CA for client verification
echo "Copying root CA..."
cp ~/.step/certs/root_ca.crt "$CERT_DIR/root_ca.crt"

# Generate server certificate for Caddy
# Include all the hostnames Caddy will serve
echo "Generating server certificate..."
step-cli ca certificate \
  "gateway.neverlight.local" \
  "$CERT_DIR/server.crt" \
  "$CERT_DIR/server.key" \
  --san "ollama.neverlight.local" \
  --san "lobehub.neverlight.local" \
  --san "casdoor.neverlight.local" \
  --san "localhost" \
  --san "abyss" \
  --san "abyss.tailce879b.ts.net" \
  --san "100.88.179.27" \
  --not-after 24h \
  --provisioner "admin@neverlight.local" \
  --provisioner-password-file "$PW_FILE" \
  --force

# Cleanup temp password file if we created it
if [ "$CLEANUP_PW" = "1" ]; then
  rm -f /tmp/.step-pw
fi

echo ""
echo "=== Server certificate generated ==="
step-cli certificate inspect "$CERT_DIR/server.crt" --short

echo ""
echo "=== Certificates in $CERT_DIR ==="
ls -la "$CERT_DIR"

# Restart Caddy if running in docker
if docker compose -f "$SCRIPT_DIR/../docker-compose.yml" ps caddy 2>/dev/null | grep -q "running"; then
  echo ""
  echo "Restarting Caddy to load new certificates..."
  docker compose -f "$SCRIPT_DIR/../docker-compose.yml" restart caddy
fi

echo ""
echo "Certificate renewal complete."
