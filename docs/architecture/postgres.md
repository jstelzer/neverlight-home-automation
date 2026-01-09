That’s the right posture, and the “break glass” story is exactly how grown-up systems get operated.

A few small refinements you can bake into the POC so it stays true even when things get messy later:

## Make “5432 unreachable” true at *every* layer

You want defense in depth, not “we promise.”

### 1) Docker/host layer

* In Compose: **no `ports:` for postgres** (only `expose:` is fine)
* Bind Postgres only to the docker network interface (default container behavior is fine)
* If you want to be extra strict: put postgres on a dedicated internal network only the `pg-mtls` container can join.

### 2) OS firewall (optional but strong)

On `abyss`, you can add an explicit “never accept 5432” rule on `tailscale0` and public interfaces. That makes “oops I published it” much harder.

### 3) Cloud layer (for EC2/RDS cases)

If this were RDS/EC2 security groups, you already have the right break-glass:

* SG inbound 5432 normally **closed**
* “temporary allow” requires console access + generates alarms + is time-bounded

That’s a solid control story.

## Make the break-glass path intentional and auditable

Two practical best practices:

### A) Add a *timer* to break-glass

When you open 5432, it should auto-close. Common ways:

* a scheduled Lambda / SSM automation that reverts the SG after N minutes
* a runbook that requires setting an “expires_at” tag and a scheduled cleanup checks it

### B) Alarm on “who opened it” and “how long it stayed open”

CloudWatch (or CloudTrail + alerts) should answer:

* which principal changed the SG
* what rule was added
* duration until reverted

## Envoy as the single choke point: make it visible

Since you want Envoy logs as audit truth, two toggles matter:

* **log every connection attempt** (including mTLS handshake failures)
* **stable identity in logs** (cert subject / URI SAN / SPIFFE ID once you add SPIRE)

That gives you the “normal path” audit record, and the DB logs answer “what queries.”

## One operational trap to avoid

“Single chokepoint” becomes “single failure point” unless you decide what happens when Envoy is down:

* fail closed (secure, but outage)
* or have a controlled fallback (break-glass)

Most systems choose **fail closed** + documented break-glass (what you described). That’s coherent.

If you want, paste the rough shape of your `pg-mtls` listener (even just ports + where it forwards), and I’ll sanity-check the bypass resistance and what to log so your audit trail is airtight while keeping the POC simple.


Yep — that’s the right prioritization.

For a Compose POC, you’re proving **the contract**:

* only the gateway/sidecar is routable
* mTLS identity is enforced there
* apps/ops tooling use localhost-to-sidecar
* 5432 stays dark

HA is a *deployment topology* problem, not a conceptual one.

In “real prod” terms, your statement maps cleanly to the standard patterns:

* **Per-workload sidecars** scale automatically with replicas (each pod/task gets its own Envoy)
* A DB access gateway can be:

  * **per node** (DaemonSet style in k8s)
  * **per pod** (sidecar) for each client
  * **a small replicated gateway tier** fronting the DB
* The DB itself is still the stateful bottleneck; multiple Envoys just avoid the proxy being the bottleneck/SPOF

So for your POC, the right focus is:

* correctness of routing and enforcement
* reproducible config shape
* observability / logs proving the chain

And then in the “prod notes” section you can explicitly call out:

* replicate `pg-mtls` gateway (N instances) behind an internal LB
* keep “5432 closed” invariant at SG/network policy level
* health checks + readiness for gateway
* fail-closed behavior and break-glass runbook

If you want a crisp one-liner for the doc:

> **POC validates the trust boundary and the routing contract; production adds redundancy around the enforcement point, not around the application logic.**

That’s the right separation of concerns.

