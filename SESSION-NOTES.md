# Session Notes - 2026-01-09

## What We Did

### 1. Documentation Reorganization
- Created proper structure: `docs/concepts/`, `docs/setup/`, `docs/architecture/`, `docs/presentations/`
- Added `docs/index.md` as reading guide with recommended order
- Archived draft/vision docs to `archive/`
- Cleaned up stale TODO.md, replaced with roadmap in README

### 2. Casdoor OIDC Integration
- Added Casdoor service to docker-compose (SQLite backend for simplicity)
- Configured Lobehub for NextAuth with Casdoor provider
- Updated Caddyfile:
  - Lobehub (9444): Regular HTTPS, OIDC auth (no client cert required)
  - Casdoor (8443): Regular HTTPS, login UI
  - Ollama (9443): Still mTLS (operators/automation)
- Added `extra_hosts` to envoy-lobehub for OIDC token exchange
- Added `NODE_EXTRA_CA_CERTS` so Lobehub trusts our CA

## Commits Made
- `8fe1e73` - Reorganize documentation structure
- `c1bbfd3` - Add Casdoor OIDC integration for browser-based auth

## Not Yet Tested
The OIDC flow is configured but not tested. May need debugging.

### To Test:
1. Add hosts entries: `127.0.0.1 lobehub.neverlight.local casdoor.neverlight.local`
2. Regenerate certs: `./scripts/gen-certs.sh` (adds casdoor SAN)
3. Start stack: `docker compose up -d`
4. Access Casdoor admin: https://casdoor.neverlight.local:8443
   - Login: admin / neverlight-admin
   - Set password for kat user
5. Test Lobehub: https://lobehub.neverlight.local:9444
   - Should redirect to Casdoor login
   - After login, should be authenticated in Lobehub

### Potential Issues to Watch:
- **OIDC issuer mismatch**: AUTH_CASDOOR_ISSUER must match what's in tokens
- **Certificate trust**: Lobehub needs our CA trusted for OIDC calls
- **Casdoor health check**: May need adjustment if different endpoint
- **Init data**: The init_data.json format may need tweaking for Casdoor version

## Remaining Work

### For "Publishable" State:
- [ ] Test OIDC flow end-to-end
- [ ] Debug any issues
- [ ] Add OPA for policy enforcement
- [ ] Create Neverlight Policy v0 (Rego file)
  - One human rule (OIDC claims → access)
  - One workload rule (SPIFFE ID → access)
  - One deny-by-default rule
  - One break-glass rule

### Nice to Have:
- [ ] Postgres backend for Casdoor (instead of SQLite)
- [ ] Postgres backend for Lobehub (for chat history persistence)
- [ ] Automated bootstrap script

## Key Files Changed
- `docker-compose.yml` - Added casdoor service, updated lobehub env
- `Caddyfile` - Added casdoor endpoint, removed mTLS from lobehub
- `scripts/gen-certs.sh` - Added casdoor.neverlight.local SAN
- `casdoor/conf/app.conf` - Casdoor server config
- `casdoor/conf/init_data.json` - Initial users, orgs, applications
- `docs/architecture/casdoor.md` - Full setup guide

## Environment Variables Needed
From `.envrc`:
- `AUTH_CASDOOR_ID` - Client ID for Lobehub app
- `AUTH_CASDOOR_SECRET` - Client secret for Lobehub app
- `NEXT_AUTH_SECRET` - NextAuth session secret
- `POSTGRES_USERNAME` / `POSTGRES_PASSWORD` - For postgres service

## Branch
All work is on the `trust` branch.
