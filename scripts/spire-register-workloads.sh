#!/bin/bash
#
# Register workloads with SPIRE Server
# Maps Docker container selectors to SPIFFE IDs
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Run spire-server commands inside the container
spire_server() {
    docker compose -f "${PROJECT_DIR}/docker-compose.yml" exec -T spire-server \
        /opt/spire/bin/spire-server "$@"
}

echo "==> Creating SPIRE registration entries"
echo ""

# First, create a join token for the agent (if not already joined)
echo "==> Generating join token for agent..."
JOIN_TOKEN=$(spire_server token generate -spiffeID spiffe://neverlight.local/agent/local -ttl 3600 | grep -oP 'Token: \K.*' || true)

if [[ -n "${JOIN_TOKEN}" ]]; then
    echo "    Token: ${JOIN_TOKEN}"
    echo "    (Use this to bootstrap the agent if needed)"
    echo ""
fi

# Create node entry for the local agent
echo "==> Creating agent node entry..."
spire_server entry create \
    -spiffeID spiffe://neverlight.local/agent/local \
    -selector join_token:trust_domain:neverlight.local \
    -node 2>/dev/null || echo "    (entry may already exist)"

# Workload: Ollama
echo "==> Registering Ollama workload..."
spire_server entry create \
    -spiffeID spiffe://neverlight.local/workload/ollama \
    -parentID spiffe://neverlight.local/agent/local \
    -selector docker:label:spiffe.io/workload:ollama \
    2>/dev/null || echo "    (entry may already exist)"

# Workload: Lobehub
echo "==> Registering Lobehub workload..."
spire_server entry create \
    -spiffeID spiffe://neverlight.local/workload/lobehub \
    -parentID spiffe://neverlight.local/agent/local \
    -selector docker:label:spiffe.io/workload:lobehub \
    2>/dev/null || echo "    (entry may already exist)"

# Workload: Postgres (for future use)
echo "==> Registering Postgres workload..."
spire_server entry create \
    -spiffeID spiffe://neverlight.local/workload/postgres \
    -parentID spiffe://neverlight.local/agent/local \
    -selector docker:image_id:postgres \
    2>/dev/null || echo "    (entry may already exist)"

echo ""
echo "==> Listing all registration entries:"
spire_server entry show

echo ""
echo "==> Done! Workloads are now registered."
echo ""
echo "To verify an SVID can be fetched, exec into a workload container and use:"
echo "  /opt/spire/bin/spire-agent api fetch x509 -socketPath /tmp/spire-agent/public/api.sock"
