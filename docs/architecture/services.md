# Abyss Services Architecture

## Overview

Hosting apps on the tailnet for personal use (me + Kat). Each app gets its own port on `abyss.tailce879b.ts.net`, all behind Caddy with Tailscale-issued TLS.

**Key principle:** Port-per-app. Every app owns `/` natively. No path prefixes, no base path hacks, no URI rewriting.

## Architecture

```
:443  → Landing page (index linking to all apps)
:444  → LobeChat
:445  → Casdoor (identity/SSO)
:446  → Feralcam (Reolink recordings)
```

- Single TLS cert covers the hostname across all ports
- Caddy terminates TLS on each port, proxies to localhost services
- Apps run on boring high ports bound to `127.0.0.1`

## Docker Compose

```yaml
services:
  lobechat:
    image: lobehub/lobe-chat-database:latest
    container_name: lobechat
    restart: unless-stopped
    environment:
      # DB, MinIO, auth, Ollama config here
    networks: [apps-net]
    ports:
      - "127.0.0.1:3210:3210"

  casdoor:
    image: casbin/casdoor:latest
    container_name: casdoor
    restart: unless-stopped
    environment:
      RUNNING_IN_DOCKER: "true"
      driverName: "sqlite3"
      dataSourceName: "file:casdoor.db?cache=shared&_fk=1"
      httpport: "8000"
    volumes:
      - ./casdoor-data:/data
    networks: [apps-net]
    ports:
      - "127.0.0.1:18000:8000"

networks:
  apps-net:
    name: apps-net
```

## Caddyfile

```caddyfile
{
    admin "unix//run/caddy/admin.socket"
}

# Landing page - app index
abyss.tailce879b.ts.net {
    tls /etc/caddy/abyss.tailce879b.ts.net.crt /etc/caddy/abyss.tailce879b.ts.net.key
    root * /var/lib/caddy/apps
    file_server
    log {
        output file /var/log/caddy/access.log
        format json
    }
}

# LobeChat
abyss.tailce879b.ts.net:444 {
    tls /etc/caddy/abyss.tailce879b.ts.net.crt /etc/caddy/abyss.tailce879b.ts.net.key
    reverse_proxy 127.0.0.1:3210
    log {
        output file /var/log/caddy/lobechat.log
        format json
    }
}

# Casdoor (identity/SSO)
abyss.tailce879b.ts.net:445 {
    tls /etc/caddy/abyss.tailce879b.ts.net.crt /etc/caddy/abyss.tailce879b.ts.net.key
    reverse_proxy 127.0.0.1:18000
    log {
        output file /var/log/caddy/casdoor.log
        format json
    }
}

# Feralcam (Reolink recordings)
abyss.tailce879b.ts.net:446 {
    tls /etc/caddy/abyss.tailce879b.ts.net.crt /etc/caddy/abyss.tailce879b.ts.net.key
    root * /var/lib/caddy/reolink

    @videos path *.mp4 *.mov *.avi *.mkv
    header @videos Content-Type video/mp4

    @hls path *.m3u8
    header @hls Content-Type application/vnd.apple.mpegurl

    @tsfiles path *.ts
    header @tsfiles Content-Type video/MP2T

    file_server browse {
        hide .*
    }
    log {
        output file /var/log/caddy/feralcam.log
        format json
    }
}
```

## Landing Page

Place at `/var/lib/caddy/apps/index.html`:

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <title>Abyss · Apps</title>
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <style>
    body {
      margin: 0;
      font-family: system-ui, sans-serif;
      background: #02030a;
      color: #f5f5f5;
      display: flex;
      min-height: 100vh;
      align-items: center;
      justify-content: center;
    }
    .grid {
      display: grid;
      gap: 1.5rem;
      grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
      max-width: 960px;
      width: 100%;
      padding: 2rem;
    }
    .card {
      background: rgba(10, 10, 25, 0.9);
      border-radius: 0.75rem;
      padding: 1.25rem 1.5rem;
      border: 1px solid rgba(120, 120, 160, 0.4);
      box-shadow: 0 18px 40px rgba(0, 0, 0, 0.7);
      transition: transform 0.15s ease, box-shadow 0.15s ease,
        border-color 0.15s ease;
      text-decoration: none;
      color: inherit;
    }
    .card:hover {
      transform: translateY(-3px);
      box-shadow: 0 22px 55px rgba(0, 0, 0, 0.85);
      border-color: #7f5af0;
    }
    .card h2 {
      margin: 0 0 0.4rem;
      font-size: 1.1rem;
    }
    .card p {
      margin: 0;
      font-size: 0.9rem;
      opacity: 0.8;
    }
    header {
      grid-column: 1 / -1;
      margin-bottom: 0.5rem;
    }
    header h1 {
      margin: 0 0 0.25rem;
      font-size: 1.4rem;
    }
    header span {
      opacity: 0.75;
      font-size: 0.9rem;
    }
  </style>
</head>
<body>
  <main class="grid">
    <header>
      <h1>Abyss · Control Deck</h1>
      <span>Pick your toy.</span>
    </header>

    <a class="card" href="https://abyss.tailce879b.ts.net:444/">
      <h2>LobeChat</h2>
      <p>AI console (Ollama / DeepSeek / whatever else).</p>
    </a>

    <a class="card" href="https://abyss.tailce879b.ts.net:445/">
      <h2>Casdoor</h2>
      <p>Identity & SSO. Users, apps, MFA.</p>
    </a>

    <a class="card" href="https://abyss.tailce879b.ts.net:446/">
      <h2>Feral Cam</h2>
      <p>Reolink recordings and captures.</p>
    </a>

    <!-- Add more tiles as needed -->
  </main>
</body>
</html>
```

## Notes

- OAuth redirect URIs for Casdoor-protected apps use the full `https://abyss...:port/callback` format
- Adding a new app: pick next port, add docker service, add Caddy block, add tile to index
- Cert is hostname-bound, not port-bound - single cert works for all listeners
