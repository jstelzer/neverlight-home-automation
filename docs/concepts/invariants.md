##  ZERO TRUST — THE OPERATOR INVARIANTS

### **Invariant 1 — Identity Is the Only Primitive**

**If identity is unclear, access does not exist.**

* IPs, subnets, VPCs, and firewalls are *routing conveniences*, not trust anchors.
* Every request must present a cryptographic identity.
* Anonymous internal traffic is a defect.

**Consequence if violated:**
You cannot reason about access, audit behavior, or contain blast radius.

---

### **Invariant 2 — Authentication Must Be Mutual**

**One-way trust is not trust.**

* Servers authenticate clients.
* Clients authenticate servers.
* TLS without client identity is incomplete.

**Consequence if violated:**
You have recreated perimeter security with extra steps.

---

### **Invariant 3 — Credentials Must Be Short-Lived**

**Long-lived secrets guarantee long-lived breaches.**

* Certificates, tokens, and credentials must expire quickly.
* Rotation must be automatic and boring.
* Manual renewal is a latent outage.

**Consequence if violated:**
Compromise persistence becomes the default.

---

### **Invariant 4 — Compromise Is Assumed**

**Design for failure, not heroics.**

* Keys will leak.
* Machines will be owned.
* Humans will misconfigure things.

Your system must fail *closed*, *locally*, and *predictably*.

**Consequence if violated:**
You are relying on luck and pager fatigue.

---

### **Invariant 5 — Authorization Is Explicit and Narrow**

**Access is granted per action, not per environment.**

* “Internal” is not a permission.
* Roles must be scoped to what is required *now*.
* Default access is **none**.

**Consequence if violated:**
Lateral movement becomes trivial.

---

### **Invariant 6 — Trust Is Never Transitive**

**Just because A can talk to B does not mean A can talk to C.**

* No implicit chaining of trust.
* Each hop re-authenticates.
* Each boundary enforces policy independently.

**Consequence if violated:**
A single compromise becomes systemic.

---

### **Invariant 7 — The Network Is Hostile by Default**

**Assume the wire is owned.**

* Encrypt everything.
* Authenticate everything.
* Log suspicious failures, not success spam.

**Consequence if violated:**
You are vulnerable to interception, spoofing, and replay.

---

### **Invariant 8 — Failure Must Be Obvious and Boring**

**Security failures should look like misconfiguration, not mystery.**

* Expired cert? Clear error.
* Unknown identity? Denied.
* No fallback modes that “just let it through.”

**Consequence if violated:**
Engineers disable security to restore service.

---

### **Invariant 9 — Humans Are Not Runtime Dependencies**

**If a human must intervene to keep trust working, the system is broken.**

* No manual cert copying.
* No shared secrets in Slack.
* No “just this once” exceptions.

**Consequence if violated:**
Your security posture degrades under stress.

---

### **Invariant 10 — Observability Is Part of the Control Plane**

**If you can’t see trust decisions, you don’t have trust.**

* AuthN/AuthZ decisions must be inspectable.
* Denials matter more than allows.
* Logs should explain *why*, not just *what*.

**Consequence if violated:**
Incidents turn into archaeology.

---

### **Invariant 11 — Tooling Must Be Replaceable**

**Vendor lock-in is an operational risk.**

* Zero trust is architecture, not a product.
* Components must be swappable without rewriting the model.
* Open protocols > proprietary glue.

**Consequence if violated:**
You trade one perimeter for another.

---

### **Invariant 12 — Operators Must Be Able to Reason About the System**

**If it cannot be explained on a whiteboard, it cannot be trusted.**

* Every trust decision should have a rationale.
* Debug paths must exist.
* Complexity must buy you something tangible.

**Consequence if violated:**
The system becomes superstition.

---

## The Meta-Invariant (the one people *feel*)

> **Security that burns operators will be dismantled by operators.**

Everything above exists to prevent that outcome.

