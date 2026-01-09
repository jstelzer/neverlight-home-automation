# Neverlight Documentation

This is a zero-trust home infrastructure stack. It proves that identity-based security isn't just for Google and Netflix - it's achievable with open-source tools, in your basement, with actual operational clarity.

## Reading Order

### Start Here: The Mental Model

1. **[concepts/invariants.md](concepts/invariants.md)** - The 12 operator invariants. These are the non-negotiable principles. Read this first.

2. **[concepts/zero-trust.md](concepts/zero-trust.md)** - What zero trust actually means (not the vendor pitch).

3. **[concepts/identity-planes.md](concepts/identity-planes.md)** - The three realms: user identity (OIDC), device identity (Tailscale), workload identity (SPIRE). They stack, not compete.

### Then: How It's Built

4. **[concepts/routing.md](concepts/routing.md)** - How Envoy routing works. The key insight: "Envoy does not know what app-a wants. Envoy is pre-configured to decide on app-a's behalf." This is the declarative vs imperative shift that trips people up.

5. **[architecture/sidecars.md](architecture/sidecars.md)** - The sidecar pattern. Sidecars are the routable identities of services.

6. **[architecture/services.md](architecture/services.md)** - What's in the stack: Ollama, Lobehub, Postgres, SPIRE, Caddy.

7. **[architecture/postgres.md](architecture/postgres.md)** - The dual-listener pattern: port 5432 for workload mTLS (SPIRE), port 5433 for human mTLS (step-ca).

### Setup & Operations

8. **[setup/pki.md](setup/pki.md)** - Full PKI setup guide. step-ca, client certs, systemd services, remote node bootstrap, SPIRE integration.

### Future: Policy

9. **[architecture/policy.md](architecture/policy.md)** - Notes on OPA integration. Two identity planes, two lifecycles, one policy layer.

10. **[architecture/casdoor.md](architecture/casdoor.md)** - Adding OIDC for human identity. The missing keystone.

---

## Presentations

For demos or explaining this to others:

- **[presentations/demo.md](presentations/demo.md)** - 5-7 minute demo flow. Prove identity, fail without cert, succeed with cert, show rotation.

- **[presentations/punchline.md](presentations/punchline.md)** - The story of accidentally testing the hardest topology: EC2 in a private subnet, behind hard NAT, through a DERP relay, with full mTLS. It worked.

---

## The Core Insight

> **"Zero trust makes the system say 'no' before it hurts you."**

The old system trusted by default and hoped you were careful.
The new system denies by default and lets you be confident.

---

## Architecture at a Glance

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

Identity Planes:
  step-ca  → human identity (operators, mTLS client certs)
  SPIRE    → workload identity (attestation, SVIDs)
```

---

## What's Not Here (Yet)

- **OPA policy engine** - Will provide unified authorization across both identity planes
- **Casdoor integration** - OIDC for humans, so browsers don't need client certs
- **Neverlight Identity Agent** - The "invisible mTLS" vision for end users

See `archive/` for draft designs and future direction.
