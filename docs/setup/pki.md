# Neverlight PKI Setup

**Trust Domain:** `neverlight.local`
**Primary Host:** `abyss` (Tailscale exit node: 100.88.179.27)
**Tailnet:** `tailce879b.ts.net`
**CA Fingerprint:** `6d3ba8bf6e28a21cc7307d70b622ef8f45e74a930aec3fc24a4a269f5af79d5b`

For a presentation-friendly zero trust primer, see `PKI-INTRO.md`.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      Tailscale Mesh                             │
│   ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐        │
│   │  abyss   │  │maledic-  │  │ avernus  │  │   EC2    │        │
│   │  (CA)    │  │  tion    │  │  (iOS)   │  │(verified)│        │
│   └────┬─────┘  └──────────┘  └──────────┘  └──────────┘        │
│        │                                                        │
│        ▼                                                        │
│   ┌─────────────────────────────────────────────────────┐       │
│   │  step-ca (:8443)           Caddy Gateway            │       │
│   │  ├─ ACME provisioner       ├─ :9443 → Ollama        │       │
│   │  └─ JWK provisioner        └─ :9444 → Lobehub       │       │
│   │                                                     │       │
│   │  mTLS: client cert required for all services        │       │
│   └─────────────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────────┘
```

---

## Quick Start (From Scratch)

```bash
cd /home/mental/projects/neverlight-forge-env/neverlight-home-automation

# 1. Generate server certs (requires provisioner password)
./gen-certs.sh "<provisioner-password>"

# 2. Generate client cert for yourself
./gen-client-cert.sh mental "<provisioner-password>"

# 3. Start the stack
docker compose up -d

# 4. Test mTLS access
curl --cert certs/mental.crt --key certs/mental.key \
     --cacert certs/root_ca.crt \
     --resolve ollama.neverlight.local:9443:127.0.0.1 \
     https://ollama.neverlight.local:9443/api/tags
```

---

## Phase 1: CA Setup on Abyss

### 1.1 Create Dedicated Step User

The `step` user owns all PKI state. This makes backup trivial.

```bash
# Create system user with home directory
sudo useradd -r -m -d /home/step -s /bin/bash step

# Add STEPPATH to bashrc
sudo -u step bash -c 'echo "export STEPPATH=/home/step/.step" >> /home/step/.bashrc'

# Create directories
sudo -u step mkdir -p /home/step/.step /home/step/backups
```

### 1.2 Directory Structure

```
/home/step/
├── .step/                    # STEPPATH - all CA state lives here
│   ├── config/
│   │   ├── ca.json           # CA configuration
│   │   └── defaults.json     # CLI defaults
│   ├── certs/
│   │   ├── root_ca.crt       # Root certificate (755 - public)
│   │   └── intermediate_ca.crt
│   ├── secrets/
│   │   ├── intermediate_ca_key
│   │   └── password          # CA password file (600)
│   └── db/                   # BadgerDB certificate database
└── backups/                  # Local backup staging
```

### 1.3 Initialize the CA

```bash
# Run as step user
sudo -u step bash /path/to/init-ca.sh

# Or manually:
sudo -u step -i
export STEPPATH=/home/step/.step

step-cli ca init \
  --name="Neverlight CA" \
  --dns="abyss.tailce879b.ts.net" \
  --dns="abyss" \
  --dns="localhost" \
  --dns="100.88.179.27" \
  --address=":8443" \
  --provisioner="admin@neverlight.local" \
  --acme
```

**Output includes the root fingerprint - save this!**

### 1.4 Fix Permissions

After init, make certs readable (they're public):

```bash
sudo chmod 755 /home/step/.step/certs
sudo chmod 644 /home/step/.step/certs/*.crt
```

### 1.5 Copy Root Cert to System Location

```bash
sudo cp /home/step/.step/certs/root_ca.crt /etc/ssl/certs/neverlight-root.crt
```

---

## Phase 2: Systemd Service

### 2.1 Install Service File

```bash
sudo cp step-ca.service /etc/systemd/system/
```

Service file contents:
```ini
[Unit]
Description=Smallstep CA - Neverlight PKI
After=network-online.target
Wants=network-online.target

[Service]
User=step
Group=step
Environment=STEPPATH=/home/step/.step
ExecStart=/usr/bin/step-ca /home/step/.step/config/ca.json --password-file=/home/step/.step/secrets/password
Restart=on-failure
RestartSec=10

# Security hardening
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths=/home/step/.step/db
PrivateTmp=yes

[Install]
WantedBy=multi-user.target
```

### 2.2 Store Password

```bash
sudo -u step bash -c 'echo "YOUR_CA_PASSWORD" > /home/step/.step/secrets/password'
sudo -u step chmod 600 /home/step/.step/secrets/password
```

### 2.3 Enable and Start

```bash
sudo systemctl daemon-reload
sudo systemctl enable step-ca
sudo systemctl start step-ca
sudo systemctl status step-ca
```

### 2.4 Verify CA is Running

```bash
curl -sk https://localhost:8443/health
# {"status":"ok"}

curl -sk https://localhost:8443/acme/acme/directory | jq .
```

---

## Phase 3: Client Bootstrap

### 3.1 Bootstrap step-cli for Your User

```bash
step-cli ca bootstrap \
  --ca-url https://localhost:8443 \
  --fingerprint 6d3ba8bf6e28a21cc7307d70b622ef8f45e74a930aec3fc24a4a269f5af79d5b
```

This creates `~/.step/` with CA trust info.

### 3.2 Test Certificate Issuance

```bash
step-cli ca certificate "test.neverlight.local" test.crt test.key \
  --provisioner "admin@neverlight.local" \
  --provisioner-password-file /path/to/password \
  --not-after 1h
```

---

## Phase 4: mTLS Gateway (Docker)

### 4.1 Architecture

```
Client (with cert) → Caddy (:9443/:9444) → Backend Services
                         │
                         ├─ Validates client cert against root_ca.crt
                         ├─ Presents server.crt to client
                         └─ Proxies to internal Docker network
```

### 4.2 Generate Gateway Certificates

```bash
./gen-certs.sh "<provisioner-password>"
```

This creates:
- `certs/server.crt` - Server cert with SANs for all hostnames
- `certs/server.key` - Server private key
- `certs/root_ca.crt` - CA root for client verification

### 4.3 Generate Client Certificates

```bash
./gen-client-cert.sh <name> "<provisioner-password>"
```

Creates `certs/<name>.crt` and `certs/<name>.key`.

### 4.4 Caddyfile Configuration

```caddyfile
# Ollama API - mTLS required
ollama.neverlight.local:9443 {
    tls /certs/server.crt /certs/server.key {
        client_auth {
            mode require_and_verify
            trust_pool file /certs/root_ca.crt
        }
    }
    reverse_proxy ollama:11434
}

# Lobehub UI - mTLS required
lobehub.neverlight.local:9444 {
    tls /certs/server.crt /certs/server.key {
        client_auth {
            mode require_and_verify
            trust_pool file /certs/root_ca.crt
        }
    }
    reverse_proxy lobehub:3210
}
```

### 4.5 Docker Compose

Services are internal-only (`expose`), Caddy is the only external entry point:

```yaml
services:
  caddy:
    ports:
      - "9443:9443"  # Ollama mTLS
      - "9444:9444"  # Lobehub mTLS
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - ./certs:/certs:ro

  ollama:
    expose:
      - "11434"  # Internal only

  lobehub:
    expose:
      - "3210"   # Internal only
```

### 4.6 Testing mTLS

```bash
# With client cert - should succeed
curl --cert certs/mental.crt --key certs/mental.key \
     --cacert certs/root_ca.crt \
     --resolve ollama.neverlight.local:9443:127.0.0.1 \
     https://ollama.neverlight.local:9443/api/tags

# Without client cert - should fail
curl --cacert certs/root_ca.crt \
     --resolve ollama.neverlight.local:9443:127.0.0.1 \
     https://ollama.neverlight.local:9443/api/tags
# Error: tlsv13 alert certificate required
```

### 4.7 Postgres Access (Human Identity)

Postgres uses a **dual-listener pattern** on envoy-postgres:

| Port | Identity Plane | Use Case                          |
|------|----------------|-----------------------------------|
| 5432 | SPIRE SVIDs    | Workload-to-workload (services)   |
| 5433 | step-ca certs  | Human operators (psql, DBeaver)   |

**How it works:**

```
┌─────────────────────────────────────────────────────────────────┐
│  psql / DBeaver / DataGrip                                      │
│    sslcert=mental.crt    ← your step-ca client identity         │
│    sslkey=mental.key                                            │
│    sslrootcert=root_ca.crt                                      │
└────────────────────────────────────────────────────────────────┬┘
                                                                 │ mTLS
                                                                 ▼
┌─────────────────────────────────────────────────────────────────┐
│  envoy-postgres:5433                                            │
│    - Validates client cert against step-ca root                 │
│    - Presents server.crt to client                              │
│    - Transport authentication complete                          │
└────────────────────────────────────────────────────────────────┬┘
                                                                 │ plaintext
                                                                 ▼
┌─────────────────────────────────────────────────────────────────┐
│  postgres:5432 (localhost, same network namespace)              │
│    - Just sees local connection                                 │
│    - Uses POSTGRES_USER/PASSWORD for DB auth                    │
└─────────────────────────────────────────────────────────────────┘
```

**Connect from abyss (local):**

```bash
# Using psql
psql "host=localhost port=5433 \
      sslmode=verify-full \
      sslcert=certs/mental.crt \
      sslkey=certs/mental.key \
      sslrootcert=certs/root_ca.crt \
      dbname=postgres user=postgres"

# Or with environment variables
export PGSSLMODE=verify-full
export PGSSLCERT=certs/mental.crt
export PGSSLKEY=certs/mental.key
export PGSSLROOTCERT=certs/root_ca.crt
psql -h localhost -p 5433 -U postgres
```

**Connect from EC2 (remote via Tailscale):**

```bash
# Assuming you've bootstrapped step-cli and have a client cert
psql "host=abyss.tailce879b.ts.net port=5433 \
      sslmode=verify-full \
      sslcert=ec2.crt \
      sslkey=ec2.key \
      sslrootcert=~/.step/certs/root_ca.crt \
      dbname=postgres user=postgres"
```

**GUI Clients (DBeaver, DataGrip):**

1. Connection type: PostgreSQL
2. Host: `localhost` (or `abyss.tailce879b.ts.net` for remote)
3. Port: `5433`
4. SSL Mode: `verify-full` or `require`
5. SSL CA Certificate: `certs/root_ca.crt`
6. SSL Client Certificate: `certs/mental.crt`
7. SSL Client Key: `certs/mental.key`

**Key insight:** The mTLS certs are for **transport authentication** (envoy validates you're a legitimate operator). Database authentication (username/password) is separate and handled by postgres itself.

---

## Phase 5: Adding Remote Nodes

### 5.1 On Any Tailnet Node (EC2, Mac, etc.)

```bash
# 1. Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up

# 2. Install step-cli
# Arch: pacman -S step-cli
# Debian: see https://smallstep.com/docs/step-cli/installation
# Mac: brew install step

# 3. Bootstrap trust to Neverlight CA
step-cli ca bootstrap \
  --ca-url https://abyss.tailce879b.ts.net:8443 \
  --fingerprint 6d3ba8bf6e28a21cc7307d70b622ef8f45e74a930aec3fc24a4a269f5af79d5b

# 4. Get a client certificate
step-cli ca certificate \
  "mynode.neverlight.local" \
  mynode.crt mynode.key \
  --provisioner "admin@neverlight.local"

# 5. Access services
curl --cert mynode.crt --key mynode.key \
     --cacert ~/.step/certs/root_ca.crt \
     https://abyss.tailce879b.ts.net:9443/api/tags
```

### 5.2 Verified: malediction (Mac) → abyss

**Tested 2025-12-10** - Full mTLS chain working over Tailscale:

```bash
# From malediction (Mac)
curl --cert mental.crt --key mental.key \
     --cacert ~/.step/certs/root_ca.crt \
     https://abyss.tailce879b.ts.net:9443/api/tags
```

Key points:
- step-cli bootstrap worked via Tailscale DNS (`abyss.tailce879b.ts.net`)
- Client cert generated on malediction, signed by abyss CA
- mTLS verified end-to-end: client presents cert → Caddy validates → proxies to Ollama

### 5.3 Verified: EC2 (Private Subnet) → abyss

**Tested 2025-12-11** - Full zero-trust chain from AWS:

```
EC2 (private subnet, no public IP, no SSH keys)
  → NAT Gateway (outbound only)
    → Tailscale mesh (identity: ip-10-100-2-171)
      → abyss:9443 (Caddy mTLS gateway)
        → client cert validated against step-ca root
          → HTTP/2 200
```

**Setup via Terraform + userdata:**
```bash
# terraform/main.tf - VPC, IGW, NAT, private subnet, security group (outbound only)
# ec2-userdata.sh - Tailscale + step-cli bootstrap on boot

terraform apply -var="ami_id=ami-XXXXX" -var="userdata=$(cat ../ec2-userdata.sh)"
```
**Access EC2 via tailscale ssh:**
```bash
tailscale ssh  root@100.102.221.50

--- prompted to visit a url and do the OIDC thing
-- drop to shell.
```

**On the EC2 instance:**
```bash
# The user-data bootstrapped tailscale and step-ca
# Get cert from CA (via Tailscale)
step-cli ca certificate "ec2.neverlight.local" ec2.crt ec2.key \
  --provisioner "admin@neverlight.local"

# Access Ollama via mTLS
curl --cert ec2.crt --key ec2.key \
     --cacert /root/.step/certs/root_ca.crt \
     https://abyss.tailce879b.ts.net:9443/api/tags
# HTTP/2 200

[root@ip-10-100-2-171 ~]# curl -D /dev/stderr  --cert ec2.crt --key ec2.key --cacert /root/.step/certs/root_ca.crt https://abyss.tailce879b.ts.net:9443/api/tags
HTTP/2 200
alt-svc: h3=":9443"; ma=2592000
server: Caddy
content-length: 0
date: Thu, 11 Dec 2025 00:13:01 GMT

## Call from datacenter in virginia tunneled over wireguard used mtls to talk to a service running in my house. 
```

**Key points:**
- No inbound security group rules - Tailscale handles connectivity
- No SSH keys needed - Tailscale SSH (`tailscale ssh root@<node>`)
- Instance bootstraps to CA automatically via userdata
- ARM64 Graviton (t4g.micro) - cheap and fast
- Ephemeral Tailscale auth key - node auto-removes when terminated
- Hard NAT means this went thru a DERP server.  Public IP would solve direct connectivity. Even with no open ports.
### 5.4 For Workloads/Services

Same process - each workload gets its own certificate identity:

```bash
step-cli ca certificate \
  "my-service.neverlight.local" \
  service.crt service.key
```

---

## Backup Strategy

The entire PKI state is in `/home/step/.step/`. Backup this directory.

```bash
# Manual backup
sudo -u step tar czf /home/step/backups/step-pki-$(date +%Y%m%d).tar.gz \
  -C /home/step .step

# Tarsnap
sudo -u step tarsnap -c -f step-pki-$(date +%Y%m%d) /home/step/.step
```

**Critical files:**
| File                          | Purpose        | Sensitivity |
|-------------------------------|----------------|-------------|
| `secrets/intermediate_ca_key` | CA signing key | CRITICAL    |
| `secrets/password`            | Key encryption | CRITICAL    |
| `certs/root_ca.crt`           | Trust anchor   | Public      |
| `db/`                         | Cert database  | Important   |

---

## Certificate Renewal

Certs are short-lived (24h max). Automated renewal is handled by systemd.

### Setup Automated Renewal

```bash
# 1. Create password file (owned by root, readable by mental)
sudo mkdir -p /etc/neverlight
sudo bash -c 'echo "YOUR_PROVISIONER_PASSWORD" > /etc/neverlight/step-pw'
sudo chmod 600 /etc/neverlight/step-pw
sudo chown mental:mental /etc/neverlight/step-pw

# 2. Install systemd units
sudo cp scripts/neverlight-cert-renewal.service /etc/systemd/system/
sudo cp scripts/neverlight-cert-renewal.timer /etc/systemd/system/

# 3. Enable and start the timer
sudo systemctl daemon-reload
sudo systemctl enable neverlight-cert-renewal.timer
sudo systemctl start neverlight-cert-renewal.timer

# 4. Verify timer is active
systemctl list-timers | grep neverlight
```

### Manual Renewal

```bash
# With password argument
./scripts/gen-certs.sh "<password>"

# Or using password file (same as automated)
./scripts/gen-certs.sh
```

The script automatically restarts Caddy if it's running.

### Check Renewal Logs

```bash
journalctl -u neverlight-cert-renewal.service -f
```

### Test Renewal Manually

```bash
sudo systemctl start neverlight-cert-renewal.service
systemctl status neverlight-cert-renewal.service
```

---

## Troubleshooting

### CA Won't Start
```bash
journalctl -u step-ca -f
```

### Permission Denied Reading Certs
```bash
# Ensure certs dir is traversable
sudo chmod 755 /home/step/.step/certs
sudo chmod 644 /home/step/.step/certs/*.crt
```

### Certificate Validation Fails
```bash
# Inspect cert
step-cli certificate inspect cert.crt --short

# Verify chain
openssl verify -CAfile root_ca.crt cert.crt

# Check expiry
step-cli certificate inspect cert.crt | grep -A2 "Validity"
```

### mTLS Connection Refused
```bash
# Check Caddy logs
docker compose logs caddy

# Verify cert SANs match hostname
step-cli certificate inspect certs/server.crt | grep -A10 "DNS Names"
```

### Port Conflicts
- step-ca: 8443
- Caddy/Ollama: 9443
- Caddy/Lobehub: 9444
- Postgres (workload mTLS): 5432
- Postgres (human mTLS): 5433

---

## Security Notes

1. **Short-lived certs** - 24h max forces regular rotation
2. **Tailscale as transport** - CA only reachable within mesh
3. **Dedicated user** - PKI isolated from main system
4. **mTLS everywhere** - No anonymous access to services
5. **Password-protected keys** - Defense in depth
6. **Systemd hardening** - Minimal privileges for CA process

---

## Files in This Directory

| File                                      | Purpose                                     |
|-------------------------------------------|---------------------------------------------|
| `docker-compose.yml`                      | Stack definition (Caddy + Ollama + Lobehub) |
| `Caddyfile`                               | mTLS gateway configuration                  |
| `certs/`                                  | Certificates directory                      |
| `scripts/init-ca.sh`                      | CA initialization script                    |
| `scripts/gen-certs.sh`                    | Server certificate generation               |
| `scripts/gen-client-cert.sh`              | Client certificate generation               |
| `scripts/step-ca.service`                 | Systemd unit file                           |
| `scripts/neverlight-cert-renewal.service` | Systemd service for cert renewal            |
| `scripts/neverlight-cert-renewal.timer`   | Systemd timer (daily at 3am)                |
| `terraform/`                              | VPC + EC2 infrastructure                    |
| `terraform/ec2-userdata.sh`               | Tailscale + step-cli bootstrap script       |

---

## Next Steps

- [x] step-ca running with ACME
- [x] Caddy mTLS gateway
- [x] Client certificate authentication
- [x] Test from malediction (Mac) - **Verified 2025-12-10**
- [x] Add EC2 instance to mesh - **Verified 2025-12-10**
- [x] Automatic cert renewal - systemd timer
- [x] Add SPIRE for workload attestation (see Phase 6 below)
- [ ] SSH certificate authority
- [ ] Casdoor for user identity (OIDC)

---

## Phase 6: SPIRE Workload Identity

**Goal:** Replace static client certs with attested workload identity. Workloads prove who they are based on *what* they are (container image, AWS instance, etc.), not pre-shared keys.

### Design Decision: Two Identity Planes

**Decision:** SPIRE runs its own CA, separate from step-ca.

> *In production orgs, human and workload identity often have separate PKI roots for blast-radius isolation and organizational separation. Neverlight uses this model: step-ca handles human identity (operators, mTLS client certs), while SPIRE handles workload identity (attestation, SVIDs). This maps to how real organizations separate these concerns — different teams, different lifecycles, different threat models. Trust bundles are federated where needed (e.g., Envoy, gateways).*

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         abyss                                   │
│                                                                 │
│  ┌─────────────────┐        ┌─────────────────────────────────┐ │
│  │    step-ca      │        │         SPIRE Server            │ │
│  │  (human plane)  │        │       (workload plane)          │ │
│  │                 │        │                                 │ │
│  │  - operators    │        │  - Docker attestor              │ │
│  │  - client certs │        │  - workload SVIDs               │ │
│  │  - mTLS gateway │        │  - service-to-service auth      │ │
│  └────────┬────────┘        └──────────────┬──────────────────┘ │
│           │                                │                    │
│           ▼                         ┌──────┴──────┐             │
│     Caddy Gateway                   │ SPIRE Agent │             │
│     (validates human certs)         └──────┬──────┘             │
│                                            │                    │
│                            ┌───────────────┼───────────────┐    │
│                            ▼               ▼               ▼    │
│                         ollama          lobehub        postgres │
│                         (SVID)          (SVID)         (SVID)   │
└─────────────────────────────────────────────────────────────────┘

Identity Planes:
  step-ca  → human identity (operators, mTLS client certs)
  SPIRE    → workload identity (attestation, SVIDs)
```

### SPIFFE IDs

| Workload        | SPIFFE ID                                          | Selector                            |
|-----------------|----------------------------------------------------|-------------------------------------|
| Ollama          | `spiffe://neverlight.local/workload/ollama`        | `docker:label:spiffe.io/workload:ollama` |
| Lobehub         | `spiffe://neverlight.local/workload/lobehub`       | `docker:label:spiffe.io/workload:lobehub` |
| Postgres        | `spiffe://neverlight.local/workload/postgres`      | `docker:image_id:postgres`          |
| EC2 ephemeral   | `spiffe://neverlight.local/workload/ec2-ephemeral` | AWS IID attestor (future)           |
| Human operator  | N/A - uses step-ca client certs directly           | mTLS                                |

### Quick Start

```bash
cd /home/mental/projects/neverlight-forge-env/neverlight-home-automation

# 1. Bootstrap SPIRE (starts server, agent, registers workloads)
./scripts/spire-bootstrap.sh

# 2. Verify SPIRE is running
docker compose exec spire-server /opt/spire/bin/spire-server healthcheck
docker compose exec spire-agent /opt/spire/bin/spire-agent healthcheck

# 3. List registered workloads
docker compose exec spire-server /opt/spire/bin/spire-server entry show
```

### Files

| File                                  | Purpose                               |
|---------------------------------------|---------------------------------------|
| `spire/server/server.conf`            | SPIRE server configuration            |
| `spire/server/data/`                  | SPIRE server data (CA keys, database) |
| `spire/agent/agent.conf`              | SPIRE agent configuration             |
| `spire/agent/data/`                   | SPIRE agent data (persisted SVID)     |
| `spire/agent/socket/`                 | Workload API socket                   |
| `scripts/spire-bootstrap.sh`          | Full SPIRE bootstrap script           |
| `scripts/spire-register-workloads.sh` | Register workloads with SPIRE         |

### Verification

```bash
# Check SPIRE server health
docker compose exec spire-server /opt/spire/bin/spire-server healthcheck

# Check SPIRE agent health
docker compose exec spire-agent /opt/spire/bin/spire-agent healthcheck

# List registration entries
docker compose exec spire-server /opt/spire/bin/spire-server entry show

# Get SPIRE's trust bundle (its self-signed root)
docker compose exec spire-server /opt/spire/bin/spire-server bundle show
```

### Next Steps

- [ ] Add Envoy sidecar for workload-to-workload mTLS using SVIDs
- [ ] Federate trust bundles (SPIRE bundle in Caddy for mixed auth)
- [ ] Add AWS IID attestor for EC2 workloads
- [ ] Policy enforcement (OPA): which SPIFFE IDs can access which services

### Resources

- SPIRE docs: https://spiffe.io/docs/latest/spire-about/
- Docker attestor: https://github.com/spiffe/spire/blob/main/doc/plugin_agent_workloadattestor_docker.md
- AWS IID attestor: https://github.com/spiffe/spire/blob/main/doc/plugin_server_nodeattestor_aws_iid.md
- SPIFFE Helper (sidecar for fetching SVIDs): https://github.com/spiffe/spiffe-helper

---

*Document created: 2025-12-10*
*Last verified working: 2025-12-10 (EC2 mTLS)*
*SPIRE integration: 2025-12-13 (two identity planes: step-ca + SPIRE)*
*Postgres human access: 2025-12-14 (dual-listener pattern on envoy-postgres)*
