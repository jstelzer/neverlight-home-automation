Yeah, totally different worlds. IAM is “cloud secret sauce,” home lab is “what dumb, resilient thing can I bolt together with Docker and a label maker.”

For docker-compose specifically, think in terms of:
	•	Sidecar proxy that does the mTLS (Envoy, Traefik, Caddy, etc.)
	•	Some identity/CA glue that hands out certs (this can be SPIRE, step-ca, or even a tiny custom CA script)

Let me give you a few concrete patterns you could actually run on abyss.

⸻

1. SPIRE + Envoy Sidecars (SPIFFE in docker-compose)

This is the “do it right” version of SPIFFE in Compose:
	•	Run a SPIRE server as one container.
	•	Run a SPIRE agent on the same Docker network.
	•	Each app service runs with an Envoy sidecar that:
	•	Talks to the SPIRE agent via SDS (secret discovery)
	•	Gets an SVID (X.509 cert) for that service
	•	Handles all mTLS for inbound/outbound traffic

Rough sketch:

services:
  spire-server:
    image: spire/spire-server:latest
    ...

  spire-agent:
    image: spire/spire-agent:latest
    ...

  app:
    image: my/app:latest
    depends_on: [spire-agent]
    networks: [mesh]
  app-proxy:
    image: envoyproxy/envoy:v1.31-latest
    depends_on: [app, spire-agent]
    networks: [mesh]
    # Envoy config: use SPIRE SDS to get certs, do mTLS to other proxies

Your app only ever talks HTTP → localhost:PORT (its Envoy sidecar).
Envoy handles mTLS + identity to other Envoy sidecars.

Pros: Real SPIFFE, clean separation, future-proof.
Cons: A little heavy for a casual home lab; Envoy config is… Envoy config.

⸻

2. Small CA + Sidecar Proxy (step-ca + Envoy/Traefik/Caddy)

If you don’t want to go full SPIRE:
	•	Run step-ca (Smallstep) as an internal CA.
	•	Each service gets a tiny sidecar that:
	•	On startup, does a CSR against step-ca
	•	Gets a short-lived cert + key
	•	Writes them to a shared volume
	•	A reverse proxy sidecar (Envoy/Traefik/Caddy) loads that cert and does mTLS.

Something like:

services:
  step-ca:
    image: smallstep/step-ca:latest

  app:
    image: my/app
    volumes:
      - app-certs:/certs

  app-cert-init:
    image: smallstep/step-cli
    command: ["step", "ca", "certificate", "app.mesh", "/certs/tls.crt", "/certs/tls.key", "--provisioner=homelab"]
    volumes:
      - app-certs:/certs

  app-proxy:
    image: traefik:v3
    volumes:
      - app-certs:/certs
    # traefik static config -> load /certs/tls.crt/key, require client cert from trusted CA

Pros: Simpler mental model, works great in docker-compose.
Cons: You’re rolling your own trust model (still fine for homelab).

⸻

3. “Just Use a Mesh” – Consul Connect or Similar

There are service meshes that can run plainly in Docker (no k8s):
	•	Consul Connect can:
	•	Act as CA
	•	Issue certs
	•	Provide sidecar proxies (Envoy) for mTLS
	•	You run a Consul agent and Envoy sidecars in your compose file.

This gives you: service discovery + mTLS + intentions (ACLs) with relatively sane UX.

⸻

4. Lightweight-ish Option: Caddy Between Services

You can also cheat:
	•	Run Caddy as a “service ingress” for each critical app.
	•	Use Caddy’s internal CA (or step-ca) and client cert auth between services.
	•	App talks HTTP behind Caddy, Caddy → Caddy use mTLS.

Example:

services:
  app:
    image: my/app
    networks: [mesh]

  app-caddy:
    image: caddy:latest
    depends_on: [app]
    networks: [mesh]
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - app-certs:/certs

Caddyfile (conceptually):

:8443 {
    tls /certs/tls.crt /certs/tls.key {
        client_auth {
            mode require_and_verify
            trusted_ca_cert_file /certs/ca.crt
        }
    }
    reverse_proxy app:8080
}

Then other services only talk to https://app-caddy:8443 with client certs.

Pros: You already like Caddy.
Cons: Less “automatic” identity, more manual CA management.

⸻

5. How This Fits Your Life Right Now

Given your preferences and tolerance for yak-shaving:
	•	If you want to feel like Google in the basement:
→ SPIRE + Envoy sidecars in docker-compose.
	•	If you want “good enough zero-trust” for homelab:
→ step-ca + sidecar proxies (Envoy/Traefik/Caddy) issuing app/client certs.
	•	If you want “I just want this secure-ish and don’t want to think”:
→ Use Tailscale for network, Caddy for HTTPS, skip internal mTLS and rely on Tailnet ACLs + good secrets.

⸻

TL;DR

Is there a sidecar or glue layer to do the mTLS with in docker-compose?

Yes:
	•	Sidecar: Envoy (classic service-mesh style)
	•	CA/identity glue: SPIRE (SVID), step-ca, or Consul Connect

For where you’re headed, the most “on brand” play is:

SPIRE server + agent in Compose, Envoy sidecars for each service, let SPIRE feed SVIDs to Envoy via SDS, mTLS everything on the mesh.

If you want, I can:
	•	Draft a docker-compose.yml skeleton with spire-server, spire-agent, and one app + envoy pair.
	•	Or show a minimal step-ca + Caddy/Traefik variant as a stepping stone before full SPIRE.
