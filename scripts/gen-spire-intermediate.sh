#!/bin/bash
#
# Generate SPIRE intermediate CA signed by step-ca root
# Outputs to /tmp for easy handoff - run as step user
#
# Usage:
#   sudo -u step ./scripts/gen-spire-intermediate.sh
#
# Then copy the output:
#   cp /tmp/spire-intermediate/* ./spire/server/
#   chmod 600 ./spire/server/intermediate-ca.key
#
set -euo pipefail

# Output location - neutral ground
OUTPUT_DIR="/tmp/spire-intermediate"

# step-ca paths
STEPPATH="${STEPPATH:-/home/step/.step}"
ROOT_CRT="${STEPPATH}/certs/root_ca.crt"
ROOT_KEY="${STEPPATH}/secrets/root_ca_key"

# Check if we can access root CA key
if [[ ! -r "${ROOT_KEY}" ]]; then
    echo "ERROR: Cannot read root CA key at ${ROOT_KEY}"
    echo ""
    echo "Run as step user:"
    echo "  sudo -u step $0"
    exit 1
fi

# Password file for encrypted root key
CA_PASSWORD_FILE="${STEPPATH}/secrets/password"
if [[ ! -r "${CA_PASSWORD_FILE}" ]]; then
    echo "ERROR: Cannot read password file at ${CA_PASSWORD_FILE}"
    exit 1
fi

echo "==> Generating SPIRE intermediate CA (offline signing)"
echo "    Output: ${OUTPUT_DIR}/"
echo ""

# Clean slate
rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"

# Template for intermediate CA with pathlen=1 (allows SPIRE to create sub-CA)
TEMPLATE_FILE="${OUTPUT_DIR}/template.json"
cat > "${TEMPLATE_FILE}" <<'EOF'
{
    "subject": {{ toJson .Subject }},
    "keyUsage": ["certSign", "crlSign"],
    "basicConstraints": {
        "isCA": true,
        "maxPathLen": 1
    }
}
EOF

# Create the intermediate CA certificate signed by root
echo "==> Creating intermediate CA signed by root (pathlen=1)..."
step-cli certificate create \
    "spire-intermediate-ca.neverlight.local" \
    "${OUTPUT_DIR}/intermediate-ca.crt" \
    "${OUTPUT_DIR}/intermediate-ca.key" \
    --template "${TEMPLATE_FILE}" \
    --ca "${ROOT_CRT}" \
    --ca-key "${ROOT_KEY}" \
    --ca-password-file "${CA_PASSWORD_FILE}" \
    --not-after 8760h \
    --no-password --insecure

rm -f "${TEMPLATE_FILE}"

# Copy root CA for the bundle
echo "==> Copying root CA..."
cp "${ROOT_CRT}" "${OUTPUT_DIR}/root-ca.crt"

# Verify the chain
echo "==> Verifying certificate chain..."
openssl verify -CAfile "${OUTPUT_DIR}/root-ca.crt" "${OUTPUT_DIR}/intermediate-ca.crt"

# Make everything readable so mental can copy it
chmod 644 "${OUTPUT_DIR}"/*

echo ""
echo "==> Done! Files are in ${OUTPUT_DIR}/"
echo ""
ls -la "${OUTPUT_DIR}/"
echo ""
echo "Certificate details:"
step-cli certificate inspect "${OUTPUT_DIR}/intermediate-ca.crt" --short
echo ""
echo "==> Now copy to your project:"
echo "    cp ${OUTPUT_DIR}/intermediate-ca.crt ./spire/server/"
echo "    cp ${OUTPUT_DIR}/intermediate-ca.key ./spire/server/"
echo "    cp ${OUTPUT_DIR}/root-ca.crt ./spire/server/"
echo "    chmod 600 ./spire/server/intermediate-ca.key"
