#!/bin/bash
# Test certificate issuance from Neverlight CA
# Usage: ./test-cert.sh <provisioner-password>

cd /tmp

if [ -z "$1" ]; then
  echo "Usage: $0 <provisioner-password>"
  echo "This is the password you used when initializing the CA"
  exit 1
fi

echo "$1" > /tmp/.step-pw
chmod 600 /tmp/.step-pw

echo "Requesting certificate for test.neverlight.local..."

step-cli ca certificate \
  "test.neverlight.local" \
  test.crt test.key \
  --not-after 1h \
  --provisioner "admin@neverlight.local" \
  --provisioner-password-file /tmp/.step-pw

rm -f /tmp/.step-pw

# If successful, inspect the cert
if [ -f test.crt ]; then
  echo ""
  echo "=== Certificate issued successfully ==="
  step-cli certificate inspect test.crt --short
  echo ""
  echo "Files created:"
  ls -la /tmp/test.crt /tmp/test.key
fi
