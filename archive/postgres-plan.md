# The plan

Yep, exactly. You’ve basically stated the core principle:

> **Apps shouldn’t need to know about TLS or identity;
> sidecars handle trust. Databases are “just another app.”**

So yeah: **Envoy + SPIRE/SVID as a TCP sidecar in front of Postgres** is the move. It keeps the model pure:

* Workloads talk plain Postgres.
* Sidecars handle mTLS + SPIFFE ID + policy.
* Postgres just listens on localhost and has no idea about certs.

Let’s sketch what that looks like in Neverlight terms, so Future-You can wire it in cleanly.

---

## 1. The shape of it

On abyss (or wherever Postgres lives):

```text
client workload
  └─ local Envoy sidecar (client)
        └─ mTLS + SVID → Envoy (server) on abyss
                └─ plain TCP → localhost:5432 (Postgres)
```

So:

* **Postgres**: `127.0.0.1:5432` only, no network exposure.
* **Envoy server sidecar**: `0.0.0.0:15432` (or tailnet-only)

  * Requires mTLS
  * Validates SPIFFE ID of caller
  * Only forwards if identity is in the allowlist.
* **Envoy client sidecar** (near app or EC2):

  * Gets SVID from SPIRE agent
  * Initiates mTLS to server Envoy
  * Exposes a local port for the app: `localhost:5432`

Your app just does:

```text
PGHOST=localhost
PGPORT=5432
```

Everywhere.

Identity, routing, TLS, policy → **all delegated to sidecars.**

---

## 2. How SPIFFE/SPIRE ties in

Once SPIRE is in the mix:

* Each app/workload gets an SVID like:

  * `spiffe://neverlight.local/workload/api-admin`
  * `spiffe://neverlight.local/workload/reporting-job`
  * `spiffe://neverlight.local/workload/ec2-ephemeral`

* Envoy is configured with:

  * **Upstream TLS context** that presents its own SVID to clients (server sidecar)
  * **Downstream TLS validation** that only trusts SVIDs with allowed prefixes / entries

You end up with rules like:

* `api-admin` SVID → can connect to Postgres via Envoy
* `reporting-job` SVID → read-only access, or maybe its own listener
* `ec2-ephemeral` SVID → cannot talk to DB at all (Ollama-only)

Postgres becomes *just a local TCP socket* behind an identity firewall.

---

## 3. Why this is better than giving Postgres certs directly

You nailed it already, but to make it crisp:

**If Postgres handles TLS + identity:**

* You have to:

  * Teach DB to speak TLS correctly
  * Manage certs on the DB host
  * Configure `pg_hba.conf` with `cert` auth rules
  * Align DB’s internal idea of identities with your SPIFFE IDs or CNs
* It’s *different* from how your HTTP services work.

**With Envoy/SVID sidecar:**

* Postgres sees **plain TCP** from localhost only.
* Envoy speaks **mTLS + SPIFFE** with clients.
* Identity and policy are **homogeneous** across:

  * HTTP (Caddy/Envoy fronting apps)
  * TCP (Envoy fronting Postgres, Redis, whatever)
* You don’t couple your DB config to your trust scheme.
* You can swap DB engines later (Postgres → Cockroach → whatever) without changing identity logic.

Same story you already adopted for:

> “Apps shouldn’t know about SSL; Caddy does it.”

Now extended to:

> “DBs shouldn’t know about SSL; Envoy does it.”

Consistency wins.

---

## 4. How this will look in Neverlight docs

Later, when you wire this in, Phase X of your doc is going to be something like:

> **Phase X: Envoy + SPIRE for TCP workloads (Postgres)**
>
> * Postgres bound to localhost only (`127.0.0.1:5432`)
> * Envoy server sidecar:
>
>   * Listens on `15432` (tailnet only)
>   * Requires mTLS with SPIFFE IDs
>   * Forwards to `localhost:5432`
> * Envoy client sidecar:
>
>   * Exposes `localhost:5432` to the app
>   * Initiates mTLS to server Envoy using SVID
> * Policy:
>
>   * Only SVIDs with prefix `spiffe://neverlight.local/workload/api-*`
>     are allowed to connect.

You can literally copy-paste your Ollama/Caddy mental model, swap HTTP for TCP, and the story remains consistent.

---

So yeah: your instinct is spot-on.

* **Apps don’t care about SSL** → Caddy/Envoy handle HTTP identity.
* **DB doesn’t care about SSL** → Envoy handles TCP identity.
* **Workloads don’t manage certs** → SPIRE issues SVIDs.
* **You care about identity & policy** → that’s defined once, in the trust layer.

