# Neverlight Home Automation - Operations Guide

This document covers how to bootstrap, operate, and test the neverlight stack after a cold start or when certificates have expired.

## Architecture Overview

The stack uses **two independent identity planes**:

| Plane                 | Purpose                       | Technology | Trust Domain                |
|-----------------------|-------------------------------|------------|-----------------------------|
| **Human Identity**    | Operator mTLS, browser access | step-ca    | Local PKI                   |
| **Workload Identity** | Service-to-service mTLS       | SPIRE      | `spiffe://neverlight.local` |

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Human Access                                │
│   Browser ──► Caddy:9443/9444 ──► (step-ca mTLS) ──► Envoy:plaintext│
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                      Workload Access                                │
│   lobehub ──► localhost:11434 ──► envoy-lobehub ──► (SPIRE mTLS)    │
│           ──► envoy-ollama:11434 ──► ollama                         │
└─────────────────────────────────────────────────────────────────────┘
```

## Prerequisites

### step-ca (Human Identity)

step-ca runs as a systemd service under the `step` user:

```bash
# Check status
sudo systemctl status step-ca

# Start if not running
sudo systemctl start step-ca

# View logs
sudo journalctl -u step-ca -f
```

The service file is at `/etc/systemd/system/step-ca.service` (template in repo: `step-ca.service`).

Configuration lives in `/home/step/.step/`:
- `config/ca.json` - CA configuration
- `secrets/password` - CA password file
- `certs/root_ca.crt` - Root CA certificate

### Environment

Create `.env` file in project root (or use direnv with `.envrc`):

```bash
POSTGRES_USERNAME=your_user
POSTGRES_PASSWORD=your_password
```

## Bootstrap Sequence (Cold Start)

Run these steps when starting fresh or after extended downtime:

### 1. Start step-ca

```bash
sudo systemctl start step-ca
```

### 2. Generate Gateway Certificates

```bash
# Interactive (prompts for provisioner password)
./scripts/gen-certs.sh

# Or with password file (for automation)
# Store password in /etc/neverlight/step-pw first
./scripts/gen-certs.sh
```

This creates/renews:
- `certs/server.crt` / `certs/server.key` - Caddy server cert
- `certs/root_ca.crt` - Root CA for client verification

### 3. Bootstrap SPIRE

```bash
./scripts/spire-bootstrap.sh
```

This script:
1. Starts spire-server
2. Generates a join token
3. Runs spire-agent with the token (one-time attestation)
4. Switches to compose-managed agent (uses persisted SVID)
5. Registers workload entries

### 4. Start the Full Stack

```bash
docker compose up -d
```

Services start in dependency order:
```
spire-server → spire-agent → envoy-* → workloads → caddy
```

## Startup Order (After Bootstrap)

Once bootstrapped, the stack can be started with just:

```bash
docker compose up -d
```

The dependency chain ensures correct ordering:
- SPIRE server starts first, waits until healthy
- SPIRE agent starts, waits for server
- Envoy sidecars start, wait for agent (need SDS socket)
- Workloads start, wait for their sidecar
- Caddy starts, waits for sidecars

## Manual Testing

### Test Human Access (step-ca mTLS)

```bash
# Generate a client certificate first
./scripts/gen-client-cert.sh operator

# Test Ollama via Caddy
curl --cacert certs/root_ca.crt \
     --cert ~/.step/certs/operator.crt \
     --key ~/.step/certs/operator.key \
     https://ollama.neverlight.local:9443/api/tags

# Test Lobehub via Caddy
curl --cacert certs/root_ca.crt \
     --cert ~/.step/certs/operator.crt \
     --key ~/.step/certs/operator.key \
     https://lobehub.neverlight.local:9444/
```

### Test Workload Identity (SPIRE)

```bash
# Check SPIRE server health
docker compose exec spire-server /opt/spire/bin/spire-server healthcheck

# Check SPIRE agent health
docker compose exec spire-agent /opt/spire/bin/spire-agent healthcheck

# List registered workloads
docker compose exec spire-server /opt/spire/bin/spire-server entry show

# Check Envoy SDS is fetching certificates
docker compose logs envoy-ollama | grep -i "sds\|certificate"
docker compose logs envoy-lobehub | grep -i "sds\|certificate"
```

### Test Workload-to-Workload mTLS

```bash
# From lobehub's perspective (should work - goes through sidecar)
docker compose exec lobehub curl -s http://127.0.0.1:11434/api/tags

# Direct to envoy-ollama mTLS port (should fail without SVID)
docker compose exec caddy curl -s http://envoy-ollama:11434/api/tags
# Expected: connection refused or TLS error

# Direct to envoy-ollama plaintext port (should work)
docker compose exec caddy curl -s http://envoy-ollama:11435/api/tags
```

## Certificate Lifetimes

### SPIRE (Workload Identity)

| Certificate | TTL | Renewal                 |
|-------------|-----|-------------------------|
| CA          | 1h  | Automatic               |
| X.509 SVID  | 15m | ~7-8 min (50% lifetime) |
| JWT SVID    | 5m  | Automatic               |

Configuration in `spire/server/server.conf`.

### step-ca (Human Identity)

| Certificate | TTL | Renewal         |
|-------------|-----|-----------------|
| Server cert | 24h | Manual or timer |
| Client cert | 24h | Manual          |

Automated renewal via systemd timer:
```bash
# Enable the renewal timer
sudo systemctl enable --now neverlight-cert-renewal.timer

# Check timer status
sudo systemctl list-timers | grep neverlight
```

## Troubleshooting

### SPIRE Agent Won't Start

```bash
# Check if it's a re-attestation issue
docker compose logs spire-agent

# If "agent already attested", the persisted SVID should work
# If not, re-run bootstrap:
./scripts/spire-bootstrap.sh
```

### Envoy Can't Fetch Certificates

```bash
# Check SDS socket exists
ls -la spire/agent/socket/

# Check envoy can reach it
docker compose exec envoy-ollama ls -la /tmp/spire-agent/public/

# Check workload is registered
docker compose exec spire-server /opt/spire/bin/spire-server entry show
```

### Caddy Can't Reach Backends

```bash
# Check sidecar health
docker compose ps

# Check envoy admin
docker compose exec envoy-ollama wget -qO- http://127.0.0.1:9901/ready

# Check network connectivity
docker compose exec caddy ping envoy-ollama
```

### Certificate Expired

```bash
# Human certs (step-ca)
./scripts/gen-certs.sh
docker compose restart caddy

# Workload certs (SPIRE) - should auto-renew
# If not, check agent health and re-bootstrap if needed
```

## Scripts Reference

| Script                        | Purpose                                  |
|-------------------------------|------------------------------------------|
| `gen-certs.sh`                | Generate/renew Caddy server certificates |
| `gen-client-cert.sh`          | Generate operator client certificate     |
| `spire-bootstrap.sh`          | Bootstrap SPIRE server + agent           |
| `spire-register-workloads.sh` | Register workload SPIFFE IDs             |
| `test-cert.sh`                | Test certificate validity                |
| `test-from-remote.sh`         | Test mTLS from remote host               |
| `init-ca.sh`                  | Initialize step-ca (first-time setup)    |

## Future Plans

- [ ] EC2 instances (need AWS creds, Tailscale tokens)
- [ ] DigitalOcean nodes
- [ ] GCP integration
- [ ] Hurricane Electric (BGP/DNS)
- [ ] 5-minute SVID TTL (once renewal is solid)

## Teardown

```bash
# Stop everything
docker compose down

# Stop step-ca
sudo systemctl stop step-ca

# Clean slate (removes all data)
docker compose down -v
rm -rf spire/server/data/* spire/agent/data/*
```

After teardown, certificates will eventually expire. Use this document to rehydrate.
