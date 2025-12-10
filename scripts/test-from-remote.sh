#!/bin/bash
# Test Neverlight PKI from a remote Tailnet node
# Usage: scp this script + run it on the remote machine
#
# Prerequisites:
#   - Tailscale connected to the same tailnet
#   - step-cli installed (brew install step on Mac)

set -e

CA_URL="https://abyss.tailce879b.ts.net:8443"
CA_FINGERPRINT="6d3ba8bf6e28a21cc7307d70b622ef8f45e74a930aec3fc24a4a269f5af79d5b"
OLLAMA_URL="https://abyss.tailce879b.ts.net:9443"

echo "=== Neverlight PKI Remote Test ==="
echo ""

# Check Tailscale
echo "[1/6] Checking Tailscale..."
if ! command -v tailscale &> /dev/null; then
    echo "ERROR: Tailscale not installed"
    exit 1
fi

if ! tailscale status &> /dev/null; then
    echo "ERROR: Tailscale not running or not connected"
    exit 1
fi

echo "  ✓ Tailscale connected"
tailscale status | grep abyss || echo "  WARNING: abyss not visible in tailscale status"
echo ""

# Check step-cli
echo "[2/6] Checking step-cli..."
if ! command -v step &> /dev/null && ! command -v step-cli &> /dev/null; then
    echo "ERROR: step-cli not installed"
    echo "  Mac: brew install step"
    echo "  Linux: see https://smallstep.com/docs/step-cli/installation"
    exit 1
fi

# Use whichever is available
STEP_CMD="step"
command -v step &> /dev/null || STEP_CMD="step-cli"
echo "  ✓ Using: $STEP_CMD"
echo ""

# Test CA reachability
echo "[3/6] Testing CA reachability..."
if ! curl -sk --connect-timeout 5 "${CA_URL}/health" | grep -q "ok"; then
    echo "ERROR: Cannot reach CA at ${CA_URL}"
    echo "  Check that abyss is online and step-ca is running"
    exit 1
fi
echo "  ✓ CA is healthy"
echo ""

# Bootstrap trust
echo "[4/6] Bootstrapping trust to Neverlight CA..."
$STEP_CMD ca bootstrap \
    --ca-url "${CA_URL}" \
    --fingerprint "${CA_FINGERPRINT}" \
    --force
echo "  ✓ Trust bootstrapped to ~/.step/"
echo ""

# Get client certificate
echo "[5/6] Requesting client certificate..."
# Get short hostname (strip domain suffix if present)
HOSTNAME=$(hostname -s 2>/dev/null || hostname | cut -d. -f1 | tr '[:upper:]' '[:lower:]')
CERT_NAME="${HOSTNAME}.neverlight.local"

echo "  Certificate name: ${CERT_NAME}"
echo "  Enter the provisioner password when prompted:"
echo ""

$STEP_CMD ca certificate \
    "${CERT_NAME}" \
    "${HOSTNAME}.crt" \
    "${HOSTNAME}.key" \
    --provisioner "admin@neverlight.local" \
    --not-after 24h \
    --force

echo ""
echo "  ✓ Certificate issued:"
$STEP_CMD certificate inspect "${HOSTNAME}.crt" --short
echo ""

# Test mTLS connection
echo "[6/6] Testing mTLS connection to Ollama..."
echo "  DEBUG: Using cert ${HOSTNAME}.crt"
echo "  DEBUG: Connecting to ${OLLAMA_URL}/api/tags"

RESULT=$(curl -sv --connect-timeout 10 \
    --cert "${HOSTNAME}.crt" \
    --key "${HOSTNAME}.key" \
    --cacert ~/.step/certs/root_ca.crt \
    "${OLLAMA_URL}/api/tags" 2>&1)

echo "  DEBUG: Response length: ${#RESULT}"
echo "  DEBUG: First 200 chars: ${RESULT:0:200}"
echo ""

if echo "$RESULT" | grep -q "models"; then
    echo "  ✓ mTLS connection successful!"
    echo ""
    echo "=== SUCCESS ==="
    echo "You can now access Neverlight services from this machine."
    echo ""
    echo "Example commands:"
    echo "  # Ollama API"
    echo "  curl --cert ${HOSTNAME}.crt --key ${HOSTNAME}.key --cacert ~/.step/certs/root_ca.crt ${OLLAMA_URL}/api/tags"
    echo ""
    echo "  # Lobehub (if you add hosts entry or use IP)"
    echo "  curl --cert ${HOSTNAME}.crt --key ${HOSTNAME}.key --cacert ~/.step/certs/root_ca.crt https://abyss.tailce879b.ts.net:9444/"
    echo ""
    echo "Certificate files:"
    echo "  ${PWD}/${HOSTNAME}.crt"
    echo "  ${PWD}/${HOSTNAME}.key"
    echo "  ~/.step/certs/root_ca.crt"
else
    echo "  ✗ mTLS connection failed"
    echo "  Response: $RESULT"
    exit 1
fi
