#!/bin/bash
# Neverlight EC2 Bootstrap - Tailscale + step-cli
# Usage: Paste as EC2 userdata (or pass via --user-data file://ec2-userdata.sh)

set -e

# --- CONFIG ---
TAILSCALE_AUTH_KEY="tskey-auth-ks1SMfxh7F11CNTRL-6YtEF1KxZ8dHo1bJ7Dp69d66GbpADJ5G"  # Replace with your tskey-auth-...
CA_URL="https://abyss.tailce879b.ts.net:8443"
CA_FINGERPRINT="6d3ba8bf6e28a21cc7307d70b622ef8f45e74a930aec3fc24a4a269f5af79d5b"

# --- INSTALL TAILSCALE ---
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up --auth-key="${TAILSCALE_AUTH_KEY}" --ssh

# Wait for Tailscale to be ready
sleep 5

# --- INSTALL STEP-CLI ---
# For Amazon Linux 2023 ARM64 (Graviton)
STEP_VERSION="0.27.2"
curl -LO "https://dl.smallstep.com/gh-release/cli/gh-release-header/v${STEP_VERSION}/step-cli_${STEP_VERSION}_arm64.rpm"
rpm -i "step-cli_${STEP_VERSION}_arm64.rpm"

# --- BOOTSTRAP TO NEVERLIGHT CA ---
step-cli ca bootstrap \
  --ca-url "${CA_URL}" \
  --fingerprint "${CA_FINGERPRINT}" \
  --install

echo "Tailscale + step-cli bootstrap complete"
echo "To get a certificate, run:"
echo "  step-cli ca certificate \"ec2.neverlight.local\" ec2.crt ec2.key --provisioner \"admin@neverlight.local\""
