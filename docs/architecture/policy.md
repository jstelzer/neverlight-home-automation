## Two identity planes, two lifecycles

### Human plane

* **OIDC (Casdoor)** for *people* and interactive sessions
* Long-ish session semantics (minutes/hours), MFA, group/role governance
* Managed by “IAM / Security / IT” types
* Primary outputs: **JWTs**, claims, RBAC/ABAC context

### Workload plane

* **SPIRE/SPIFFE** for *services* and non-human workloads
* Short-lived, automatically rotated identities (minutes)
* Managed by “Platform / SRE” types
* Primary outputs: **SVIDs (X.509 or JWT-SVID)** bound to attestation and runtime

## Why this separation is so healthy

* A compromised human token shouldn’t automatically grant service-to-service privileges.
* A compromised workload identity shouldn’t automatically grant interactive admin capabilities.
* Different revocation/rotation models:

  * humans: disable account, rotate secrets, revoke sessions
  * workloads: kill pod/container/node, revoke selectors/entries, let rotation erase keys fast

## Where they meet (cleanly)

They meet at policy, not at the CA.

* Gateways translate “human authn” into requests that still must pass **workload authorization**
* Sidecars enforce “workload identity” even if a human initiated the request upstream
* If you add OPA later, it becomes the single place you *compose*:

  * `subject.type = human` (Casdoor claims)
  * `subject.type = workload` (SPIFFE ID)
  * plus contextual signals (tailscale tags/posture, time, environment)

So yeah: in a real org, it’s often literally different teams and different tooling stacks — and you’re already designing like that.

If you want a tight Rosetta Stone line for this too:

> **Humans prove who they are with OIDC. Workloads prove what they are with attestation. Policies decide how (and if) those two worlds are allowed to interact.**


Blunt truth: Sidecars are the routable identities of services.

Scoped truth: Sidecars are the routable identities for service-to-service traffic; gateways exist for human access.
