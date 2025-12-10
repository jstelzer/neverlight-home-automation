#!/bin/bash
# Generate a client certificate for mTLS access
# Usage: ./gen-client-cert.sh <client-name> <provisioner-password>

set -e

CERT_DIR="$(dirname "$0")/certs"

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: $0 <client-name> <provisioner-password>"
  echo "Example: $0 mental 'your-password'"
  exit 1
fi

CLIENT_NAME="$1"
echo "$2" > /tmp/.step-pw
chmod 600 /tmp/.step-pw

echo "Generating client certificate for ${CLIENT_NAME}.neverlight.local..."
step-cli ca certificate \
  "${CLIENT_NAME}.neverlight.local" \
  "$CERT_DIR/${CLIENT_NAME}.crt" \
  "$CERT_DIR/${CLIENT_NAME}.key" \
  --not-after 24h \
  --provisioner "admin@neverlight.local" \
  --provisioner-password-file /tmp/.step-pw \
  --force

rm -f /tmp/.step-pw

echo ""
echo "=== Client certificate generated ==="
step-cli certificate inspect "$CERT_DIR/${CLIENT_NAME}.crt" --short

echo ""
echo "Test with:"
echo "  curl --cert $CERT_DIR/${CLIENT_NAME}.crt --key $CERT_DIR/${CLIENT_NAME}.key --cacert $CERT_DIR/root_ca.crt https://ollama.neverlight.local:8443/api/tags"
