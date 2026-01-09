# Neverlight Home Automation

A zero-trust home infrastructure stack using mTLS everywhere. Two identity planes, no implicit trust, short-lived credentials.

**For the full story, start with [docs/index.md](docs/index.md).**

## Quick Overview

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

## Bootstrap (Cold Start)

```bash
# 1. Ensure step-ca is running
sudo systemctl start step-ca

# 2. Generate gateway certificates
./scripts/gen-certs.sh

# 3. Bootstrap SPIRE (first time only)
./scripts/spire-bootstrap.sh

# 4. Start the stack
docker compose up -d
```

For detailed setup including CA initialization, see [docs/setup/pki.md](docs/setup/pki.md).

## Daily Operations

After initial bootstrap, just:

```bash
docker compose up -d
```

The dependency chain handles ordering automatically.

## Testing

### Human Access (step-ca mTLS)

```bash
# Generate client cert (first time)
./scripts/gen-client-cert.sh operator

# Test Ollama
curl --cacert certs/root_ca.crt \
     --cert ~/.step/certs/operator.crt \
     --key ~/.step/certs/operator.key \
     https://ollama.neverlight.local:9443/api/tags
```

### Workload Identity (SPIRE)

```bash
# Health checks
docker compose exec spire-server /opt/spire/bin/spire-server healthcheck
docker compose exec spire-agent /opt/spire/bin/spire-agent healthcheck

# List registered workloads
docker compose exec spire-server /opt/spire/bin/spire-server entry show
```

## Certificate Lifetimes

| System   | Certificate | TTL  | Renewal          |
|----------|-------------|------|------------------|
| SPIRE    | X.509 SVID  | 15m  | Automatic (~7m)  |
| SPIRE    | CA          | 1h   | Automatic        |
| step-ca  | Server cert | 24h  | Timer or manual  |
| step-ca  | Client cert | 24h  | Manual           |

Automated server cert renewal:
```bash
sudo systemctl enable --now neverlight-cert-renewal.timer
```

## Troubleshooting

### SPIRE Agent Won't Start
```bash
docker compose logs spire-agent
# If "already attested" error, persisted SVID should work
# Otherwise: ./scripts/spire-bootstrap.sh
```

### Envoy Can't Fetch Certificates
```bash
ls -la spire/agent/socket/
docker compose exec spire-server /opt/spire/bin/spire-server entry show
```

### Certificates Expired
```bash
./scripts/gen-certs.sh && docker compose restart caddy
```

## Scripts

| Script                        | Purpose                                  |
|-------------------------------|------------------------------------------|
| `scripts/gen-certs.sh`        | Generate/renew Caddy server certificates |
| `scripts/gen-client-cert.sh`  | Generate operator client certificate     |
| `scripts/spire-bootstrap.sh`  | Bootstrap SPIRE server + agent           |
| `scripts/init-ca.sh`          | Initialize step-ca (first-time setup)    |

## Teardown

```bash
docker compose down           # Stop containers
sudo systemctl stop step-ca   # Stop CA

# Full reset (removes all state)
docker compose down -v
rm -rf spire/server/data/* spire/agent/data/*
```

---

## Roadmap

### Done
- [x] step-ca for human identity (24h certs, systemd service)
- [x] SPIRE for workload identity (15m SVIDs, Docker attestation)
- [x] Envoy sidecars with SPIRE SDS integration
- [x] Caddy gateway with mTLS client verification
- [x] Postgres dual-listener (human on 5433, workload on 5432)
- [x] EC2 remote node via Tailscale mesh

### Next
- [ ] **Casdoor (OIDC)** - Human identity without client certs in browsers
- [ ] **OPA policies** - Unified authorization across both identity planes
- [ ] Automated bootstrap script (cold start in one command)

### Future
- [ ] Neverlight Identity Agent (invisible mTLS for end users)
- [ ] SSH certificate authority
- [ ] Multi-cloud workload attestation (AWS IID, GCP, etc.)

---

## Documentation

- **[docs/index.md](docs/index.md)** - Reading guide and full documentation
- **[docs/presentations/demo.md](docs/presentations/demo.md)** - 5-7 minute demo flow
- **[docs/concepts/invariants.md](docs/concepts/invariants.md)** - The 12 operator invariants
