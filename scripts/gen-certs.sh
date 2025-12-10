#!/bin/bash
# Generate certificates for the mTLS gateway
# Usage: ./gen-certs.sh <provisioner-password>

set -e

CERT_DIR="$(dirname "$0")/certs"

if [ -z "$1" ]; then
  echo "Usage: $0 <provisioner-password>"
  exit 1
fi

echo "$1" > /tmp/.step-pw
chmod 600 /tmp/.step-pw

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
  --san "localhost" \
  --san "abyss" \
  --san "abyss.tailce879b.ts.net" \
  --san "100.88.179.27" \
  --not-after 24h \
  --provisioner "admin@neverlight.local" \
  --provisioner-password-file /tmp/.step-pw \
  --force

rm -f /tmp/.step-pw

echo ""
echo "=== Server certificate generated ==="
step-cli certificate inspect "$CERT_DIR/server.crt" --short

echo ""
echo "=== Certificates in $CERT_DIR ==="
ls -la "$CERT_DIR"

echo ""
echo "Next: Generate a client certificate with:"
echo "  step-cli ca certificate 'client.neverlight.local' client.crt client.key"
