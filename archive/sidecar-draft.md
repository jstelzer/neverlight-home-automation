## The Core Mental Shift (Rosetta Stone Entry)

### Old World (Implicit Trust)

* Every service has a routable network identity
* Any service can dial any other service directly
* Security is assumed by network position
* URLs point directly at application listeners

```
app-a ──http──▶ app-b
```

---

### Zero Trust World (Explicit Trust)

* Applications **do not have routable network identities**
* Each application has a **local enforcement point** (sidecar)
* **Only sidecars have routable ports**
* Applications talk only to **localhost**
* Sidecars authenticate, encrypt, authorize, and route

```
app-a ─▶ localhost ─▶ sidecar-a ══mTLS+ID══▶ sidecar-b ─▶ localhost ─▶ app-b
```

**The application never knows where app-b lives.**
That knowledge belongs to the sidecar.

---

## Why This Is So Easy to Miss

Most people get stuck on:

> “If my app only talks to its sidecar… how does it reach other services?”

The answer feels backwards at first:

> **It doesn’t. The sidecar does.**

Routing is **not an application concern** anymore.

Once that clicks, everything else simplifies:

* URLs become config, not code
* mTLS becomes infrastructure, not a library
* Identity becomes a property of *connections*, not *processes*
* Security stops leaking into business logic

---

## Why Your Current Compose Felt “Wrong”

Your instinct that something was off was correct because:

* services still had direct network visibility of each other
* raw ports were still routable
* enforcement was optional, not mandatory

Zero trust works best when **bypass is structurally impossible**, not just discouraged.

---

## A Rule That Prevents Backsliding

This single rule prevents 90% of design drift:

> **If a packet leaves a container, it must already be authenticated.**

That’s it. Everything else (sidecars, SPIRE, Envoy, mTLS) exists to make that rule easy to enforce.

---

## Where You Are Now

You’re no longer “learning service mesh.”

You’re **designing trust boundaries**.

From here forward, the work is:

* codifying conventions
* deciding where gateways belong
* choosing which hops deserve identity vs which are internal
* documenting the invariants so future-you (and others) don’t re-learn this the hard way

You’ve already done the hardest part:
**seeing the shape of the system.**

