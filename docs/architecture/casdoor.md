# Casdoor OIDC Integration

Casdoor provides human identity via OIDC. This replaces mTLS client certificates for browser-based access while keeping workload-to-workload mTLS intact.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Human Access (OIDC)                              │
│   Browser ──► Caddy:9444 ──► Lobehub ──► NextAuth ──► Casdoor:8443 │
│                                                        ↓            │
│                                                    (SQLite)         │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                    Human Access (mTLS) - unchanged                  │
│   curl/API ──► Caddy:9443 ──► (step-ca mTLS) ──► Ollama            │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                    Workload Access - unchanged                      │
│   Lobehub ──► envoy-lobehub ──► SPIRE mTLS ──► envoy-ollama        │
└─────────────────────────────────────────────────────────────────────┘
```

## Identity Planes

| Plane | Technology | Use Case |
|-------|------------|----------|
| **Human (Browser)** | Casdoor OIDC | Lobehub web UI |
| **Human (API)** | step-ca mTLS | Ollama API, psql, automation |
| **Workload** | SPIRE SVIDs | Service-to-service |

## Prerequisites

### 1. DNS / Hosts File

Add to `/etc/hosts` on client machines:

```
# Neverlight services (replace with actual host IP)
192.168.1.100  lobehub.neverlight.local
192.168.1.100  casdoor.neverlight.local
192.168.1.100  ollama.neverlight.local
```

### 2. Environment Variables

Ensure `.envrc` or `.env` contains:

```bash
# Casdoor OIDC
AUTH_CASDOOR_ID=943e627d79d5dd8a22a1
AUTH_CASDOOR_SECRET=6ec24ac304e92e160ef0d0656ecd86de8cb563f1

# NextAuth
NEXT_AUTH_SECRET=<generate-random-string>
```

Generate a secret: `openssl rand -base64 32`

### 3. Regenerate Certificates

The server cert needs the new SAN for casdoor.neverlight.local:

```bash
./scripts/gen-certs.sh
```

## First-Time Setup

### 1. Start the Stack

```bash
docker compose up -d
```

### 2. Access Casdoor Admin

Navigate to https://casdoor.neverlight.local:8443

Default credentials (from `casdoor/conf/init_data.json`):
- Organization: `neverlight`
- Username: `admin`
- Password: `neverlight-admin`

**Change the admin password immediately.**

### 3. Verify Application Config

In Casdoor admin, check that the `lobehub` application exists with:
- Client ID: matches `AUTH_CASDOOR_ID` in your env
- Client Secret: matches `AUTH_CASDOOR_SECRET` in your env
- Redirect URI: `https://lobehub.neverlight.local:9444/api/auth/callback/casdoor`

### 4. Create User Accounts

In Casdoor admin → Users → Add User:
- Organization: `neverlight`
- Name: (username)
- Display Name: (friendly name)
- Password: (set a password)

The default `kat` user exists but needs a real password set.

## Testing the OIDC Flow

### 1. Browser Login

1. Open https://lobehub.neverlight.local:9444
2. Click "Sign in with Casdoor" (or similar)
3. Enter credentials at Casdoor login page
4. Should redirect back to Lobehub, logged in

### 2. Verify Session

Once logged in:
- Check browser cookies for session token
- Lobehub should show user identity

### 3. Verify mTLS Still Works

Ollama API still requires client certs:

```bash
# Should fail (no client cert)
curl https://ollama.neverlight.local:9443/api/tags
# Error: certificate required

# Should succeed (with client cert)
curl --cert ~/.step/certs/operator.crt \
     --key ~/.step/certs/operator.key \
     --cacert certs/root_ca.crt \
     https://ollama.neverlight.local:9443/api/tags
```

## Troubleshooting

### Casdoor won't start

```bash
docker compose logs casdoor
```

Check:
- Config file mounted correctly: `./casdoor/conf/app.conf`
- Data directory writable

### OIDC redirect fails

Check:
- Redirect URI in Casdoor matches exactly
- Client ID/Secret match between Casdoor and Lobehub env
- Browser can reach both URLs

### Token exchange fails

Check Lobehub logs:
```bash
docker compose logs lobehub
```

Common issues:
- Certificate trust: ensure `NODE_EXTRA_CA_CERTS` is set
- DNS resolution: ensure extra_hosts is set in envoy-lobehub
- Issuer mismatch: AUTH_CASDOOR_ISSUER must match Casdoor's origin

## Configuration Files

| File | Purpose |
|------|---------|
| `casdoor/conf/app.conf` | Casdoor server configuration |
| `casdoor/conf/init_data.json` | Initial users, orgs, applications |
| `Caddyfile` | HTTPS termination for all services |

## Security Notes

1. **Change default passwords** - The init_data.json has placeholder passwords
2. **Rotate secrets** - AUTH_CASDOOR_SECRET should be unique per deployment
3. **HTTPS everywhere** - Casdoor and Lobehub both use HTTPS via Caddy
4. **mTLS for operators** - API access still requires client certificates

## What This Enables

The "show it off" demo:

1. "I log in as a human (OIDC). I can reach Lobehub." ✓
2. "Lobehub can reach Ollama because its SPIFFE ID is allowed." ✓
3. "My EC2 ephemeral node can reach Ollama with client certs." ✓
4. "Browsers don't need client certificates - just login." ✓

**The Wife Test**: Kat opens Lobehub, logs in with username/password, uses the app. She never sees mTLS. It just works.
