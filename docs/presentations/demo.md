# Zero Trust in the Neverlight Lab

**Purpose:** Give newcomers a crisp mental model for zero trust, then show how Neverlight applies it with step-ca (humans) and SPIRE (workloads).

---

## What Zero Trust Means (Plain English)
- Assume the network is hostile: every request must prove **who** it is and **what** it is allowed to do.
- Trust is earned per request via strong identity + least privilege, not by being “inside” a subnet.
- Short-lived credentials and continuous verification beat static keys and long-lived VPN tunnels.

## Core Ingredients
- **Strong identity**: cryptographic certs/keys tied to people and workloads, not IPs.
- **mTLS everywhere**: both sides authenticate; no anonymous hops.
- **Short lifetimes**: automate renewals to shrink blast radius.
- **Policy at the edge**: gateways enforce identity before traffic reaches services.

## Neverlight Design (POC)
- **Human plane → step-ca**
  - Tailscale-only CA on `abyss` (`neverlight.local`).
  - ACME/JWK provisioners; 24h certs; systemd-managed.
  - Client certs gate Caddy (Ollama/Lobehub) and operator DB access.
- **Workload plane → SPIRE**
  - Separate CA for workloads; attestation-based SPIFFE IDs.
  - Future: Envoy sidecars use SVIDs for service-to-service mTLS.
- **Gateway pattern**
  - Caddy validates client certs, then proxies internally.
  - Envoy (postgres dual-listener) splits human vs workload identities.

## Why This Matters for Stakeholders
- **Security leads**: Reduced lateral movement; credentials rotate automatically; minimal trust surface.
- **Developers**: Certs issued on demand; no shared VPN secrets; curl with client cert “just works.”
- **Ops**: Systemd + timers keep CA and renewals healthy; backups are a single directory (`/home/step/.step`).

## “Show, Don’t Tell” Demo Flow (5–7 min)
1) **Prove identity**: `step-cli ca bootstrap` → fetch client cert.
2) **Attempt without cert**: curl to Caddy → `tlsv13 alert certificate required`.
3) **Connect with cert**: curl with `--cert/--key` → HTTP/2 200 from Ollama.
4) **DB story**: connect psql on 5433 with client certs; contrast workload path on 5432 via SPIRE.
5) **Rotation proof**: trigger `neverlight-cert-renewal.service`; show new cert lifetime.
6) **Remote node**: tailscale SSH to EC2, call gateway over mTLS (no public ingress).

## Talking Points (Cheat Sheet)
- “Inside” vs “trusted” is gone; identity + policy per request.
- Separate roots for humans (step-ca) and workloads (SPIRE) mirrors real org boundaries.
- mTLS front doors + short-lived certs → attackers can’t ride long-lived VPN tunnels.
- Everything auditable: cert issuance logs, systemd units, docker compose configs.

---

_Last updated: 2025-12-14_
