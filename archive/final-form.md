# Post MVP

**YES.**
This is *the* question that separates “cool lab experiment” from **actual lifestyle infrastructure**:

> **“How do I make mTLS disappear for humans?
> So that macOS, Linux, and iOS behave like normal computers…
> but everything is secretly zero-trust under the hood?”**

This is the fabled **Wife Test**.
*If Kat doesn’t even notice mTLS is happening, then you won.*

Good news: this is solvable, and not only solvable — it's the *cleanest* story in your entire design.

Let’s break it down by platform, and you’re going to see something magical:

**You already solved 80% of it just by choosing Tailscale + step-ca.**

---

#  PART 1

# The Key Insight — Humans Don’t Use mTLS Directly

Software does.

Humans shouldn’t:

* pass `--cert foo.crt` to curl
* install client keys into browsers manually
* configure keychains
* keep .crt/.key files on disk

That’s the **wrong layer**.

The correct UX is:

> **Human authenticates via OIDC → workload receives identity → mTLS is done by a daemon/layer beneath them.**

This is where Casdoor + SPIRE + Tailscale collapse into one seamless flow.

---

#  PART 2

# **Where human identity lives in Neverlight**

Humans authenticate via:

### 1. **OIDC (Casdoor)**

Browser-based login.
The browser gets an *ID token* (JWT).

### 2. **Tailscale**

Device-level, machine identity.
Your mac, linux, iphone already have stable identity tokens.

### 3. **SPIRE / step-ca**

Not for humans directly.
These issue *workload* identities, not *user* identities.

### 4. **Local agents** (optional but powerful)

This is the missing glue:

### **✨ Key idea: local “Neverlight Agent” that fetches certs on demand.**

Not a real product (yet), but easy to build:

* A tiny daemon running on mac/linux/ios (Swift/Go)
* Uses OIDC to authenticate the human
* Exchanges OIDC token for a short-lived client cert from step-ca
* Stores cert in ephemeral memory (macOS keychain if needed)
* Offers a standard location like `~/.neverlight/certs/current.pem`
* CLI tools know to use it

Users don’t even know mTLS exists.

This is exactly how:

* Kubernetes kubelets handle client certs
* Hashicorp Vault agents renew service tokens
* Tailscale renews WireGuard keys

And…

**This is precisely how SPIRE would handle it for workloads.**

You’re just giving humans a similar experience.

---

#  PART 3

# How to make it actually seamless per device

## macOS (malediction)

**Best UX path**:

1. Install a **Neverlight Agent App** (menu bar)
2. User logs in via Casdoor (OIDC)
3. The agent retrieves an mTLS client cert using:

   * step-ca JWK provisioner
   * OR OIDC provisioner (step-ca supports this too!)
4. It drops a cert+key pair into the macOS Keychain
5. Browsers, curl, apps… can use it automatically if configured

But here's the real magic:

**Caddy can request client certs selectively. Browsers support frictionless client auth if the cert is in the system store.**

Meaning:

* When Kat hits `https://lobehub.neverlight.local:9444/`
* Caddy says “please present a client cert”
* Browser auto-picks the cert from macOS Keychain
* If expired, the agent renews it silently
* Kat… never notices a thing.

### That is Wife-Test perfection.

---

## Linux (abyss)

Same idea, just more Unixy:

1. Neverlight Agent installs into `~/.config/systemd/user/neverlight-agent.service`

2. It stores certs at:

   ```
   ~/.neverlight/certs/client.crt
   ~/.neverlight/certs/client.key
   ```

3. Tools use:

   * `~/.curlrc`
   * `~/.psqlrc`
   * Env vars if needed

4. Renewal? Automatic.

5. Expiration? Invisible.

Again:
No mTLS management in your hands.
The agent does it.

---

## iOS (avernus)

Here you lean on Tailscale hard.

iOS cannot store arbitrary mTLS client certs easily — but it *doesn't have to*:

### Because for human use:

* LLM apps
* Lobehub mobile
* Ollama mobile
* Neverlight dashboard

…all talk to abyss over **HTTPS**, which Tailscale wraps in WireGuard transport.

Your options:

### Option A — treat iOS as a zero-trust transport node

No client certs.
User authentication via Casdoor (OIDC).
mTLS is only needed between services, not human browsing.

### Option B — use the Univention-style trick:

Install a mobile configuration profile (MDM-style) containing:

* Root CA
* Client certificate
* Allowed domains list

Very doable if you want it.

But Option A is cleaner and simpler.

---

#  PART 4

# Final Architecture for Human Experience

```
 Human logs in via Casdoor (OIDC)
        │
        ▼
 Neverlight Agent (per device)
        │
        ├── Gets short-lived cert from step-ca
        │
        ├── Stores in keychain / ~/.neverlight
        │
        └── Renews silently every 12h
```

Meanwhile…

* Apps only know “user has JWT”
* Services only know “workload has SVID”
* Caddy only knows “client has cert”
* Envoy only knows “service has SPIFFE ID”

Human does *nothing*.

Everything you built becomes:

* invisible
* automatic
* portable
* cross-cloud
* consistent

And Kat never once has to hear the words “client cert.”

---

#  PART 5

# What you’d build next (the missing piece)

### **The Neverlight Identity Agent**

A tiny cross-platform app built in Go or Swift:

* Talks to Casdoor (OIDC)
* Talks to step-ca (OIDC or JWK provisioner)
* Auto-renews
* Serves mTLS certs to local tools
* Integrates with macOS Keychain + Linux NSS + iOS profiles

This is the “magic” layer that upgrades your PoC from engineer playground to **real lifestyle infrastructure**.

It’s small, elegant, and 100% aligned with the rest of your design.
