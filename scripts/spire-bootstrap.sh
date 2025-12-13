#!/bin/bash
#
# Bootstrap SPIRE infrastructure
# SPIRE is its own CA (workload identity plane)
# step-ca handles human identity (separate plane)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "${PROJECT_DIR}"

echo "==> SPIRE Bootstrap"
echo ""

# Start just the SPIRE server first
echo "==> Starting SPIRE server..."
docker compose up -d spire-server

# Wait for server to be healthy
echo "==> Waiting for SPIRE server to be healthy..."
for i in {1..30}; do
    if docker compose exec -T spire-server /opt/spire/bin/spire-server healthcheck 2>/dev/null; then
        echo "    Server is healthy!"
        break
    fi
    if [[ $i -eq 30 ]]; then
        echo "ERROR: SPIRE server failed to start"
        docker compose logs spire-server
        exit 1
    fi
    sleep 2
done

# Generate join token for the agent
echo "==> Generating join token for agent..."
TOKEN_OUTPUT=$(docker compose exec -T spire-server /opt/spire/bin/spire-server token generate \
    -spiffeID spiffe://neverlight.local/agent/local \
    -ttl 600)
JOIN_TOKEN=$(echo "${TOKEN_OUTPUT}" | grep -oP 'Token: \K.*' | tr -d '\r')

if [[ -z "${JOIN_TOKEN}" ]]; then
    echo "ERROR: Failed to generate join token"
    echo "${TOKEN_OUTPUT}"
    exit 1
fi

echo "    Token: ${JOIN_TOKEN}"

# Get the network name for docker run
NETWORK_NAME=$(docker compose config --format json | jq -r '.networks | keys[0]')
FULL_NETWORK_NAME="neverlight-home-automation_${NETWORK_NAME}"

# Run agent with join token for initial attestation
# This is a one-time bootstrap - agent persists SVID for future restarts
echo "==> Running SPIRE agent with join token (initial attestation)..."
docker run -d --rm \
    --name spire-agent-bootstrap \
    --network "${FULL_NETWORK_NAME}" \
    -v "${PROJECT_DIR}/spire/agent/agent.conf:/opt/spire/conf/agent/agent.conf:ro" \
    -v "/var/run/docker.sock:/var/run/docker.sock:ro" \
    -v "${PROJECT_DIR}/spire/agent/data:/opt/spire/data/agent" \
    -v "${PROJECT_DIR}/spire/agent/socket:/tmp/spire-agent/public" \
    ghcr.io/spiffe/spire-agent:1.11.0 \
    -config /opt/spire/conf/agent/agent.conf \
    -joinToken "${JOIN_TOKEN}"

# Wait for agent to attest
echo "==> Waiting for agent to attest..."
for i in {1..15}; do
    if docker exec spire-agent-bootstrap /opt/spire/bin/spire-agent healthcheck 2>/dev/null; then
        echo "    Agent is healthy and attested!"
        break
    fi
    if [[ $i -eq 15 ]]; then
        echo "WARNING: Agent may not be fully attested yet"
        docker logs spire-agent-bootstrap | tail -20
    fi
    sleep 2
done

# Stop the bootstrap container, start via compose (will use persisted SVID)
echo "==> Switching to compose-managed agent..."
docker stop spire-agent-bootstrap 2>/dev/null || true
docker compose up -d spire-agent

sleep 3

# Verify agent is healthy
if docker compose exec -T spire-agent /opt/spire/bin/spire-agent healthcheck 2>/dev/null; then
    echo "    Agent is healthy!"
else
    echo "WARNING: Agent health check failed"
    docker compose logs spire-agent | tail -10
fi

# Register workloads
echo ""
echo "==> Registering workloads..."
"${SCRIPT_DIR}/spire-register-workloads.sh"

echo ""
echo "==> SPIRE bootstrap complete!"
echo ""
echo "Identity planes:"
echo "  step-ca        - human identity (operators, mTLS client certs)"
echo "  SPIRE          - workload identity (attestation, SVIDs)"
echo ""
echo "SPIRE trust domain: spiffe://neverlight.local"
echo ""
echo "Registered SPIFFE IDs:"
echo "  - spiffe://neverlight.local/workload/ollama"
echo "  - spiffe://neverlight.local/workload/lobehub"
echo "  - spiffe://neverlight.local/workload/postgres"
