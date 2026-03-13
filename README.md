# devpipe homelab

Self-hosted infrastructure running on a Raspberry Pi 5 at home, tunneled to a VPS for public access — no open ports required at home.

## Architecture

```
Internet
   │
   ▼
VPS (public IP)
 ├── Traefik       — SSL termination & routing
 ├── Pangolin      — Tunnel management dashboard
 └── Gerbil        — WireGuard manager
        │
        │  WireGuard tunnel
        ▼
Raspberry Pi 5 (home, no open ports)
 └── Newt          — Tunnel client (systemd service)
        │
        ▼
   Pi services (Immich, Odoo, AI...)
```

All services are accessible via `*.yourdomain.com` subdomains over HTTPS with automatic Let's Encrypt certificates.

## Hardware

| Node | Specs |
|------|-------|
| **Raspberry Pi 5** | 8 GB RAM · 938 GB NVMe · 4 GB swap · ARM64 · Debian 12 |
| **VPS** | 2 GB RAM · 50 GB disk · 1 vCPU · Ubuntu 22.04 |

## Services

### [`pi/`](./pi) — Raspberry Pi 5

| Service | Description | Port |
|---------|-------------|------|
| [Immich](https://immich.app) | Self-hosted photo library (two instances) | 2283 / 2284 |
| [Odoo](https://www.odoo.com) | ERP / online shop | 8069 |
| [AnythingLLM](https://anythingllm.com) | Local AI assistant (managed by Dokploy) | 3001 |
| [Kestra](https://kestra.io) | Workflow automation engine | 8082 |
| [Watchtower](https://containrrr.dev/watchtower) | Auto container updates (04:00 daily) | — |
| [Beszel agent](https://beszel.dev) | System metrics agent → VPS hub | 45876 |

Backup scripts in [`pi/rclone/`](./pi/rclone) — Immich and Odoo backed up daily to S3 and Google Drive.

### [`vps/`](./vps) — VPS

| Service | Description | Domain |
|---------|-------------|--------|
| [Pangolin](https://github.com/fosrl/pangolin) + Traefik | Tunnel manager + reverse proxy | pangolin.yourdomain.com |
| [Uptime Kuma](https://uptime.kuma.pet) | Service uptime monitoring | uptime.yourdomain.com |
| [Beszel hub](https://beszel.dev) | System metrics dashboard | beszel.yourdomain.com |
| [Homepage](https://gethomepage.dev) | Services dashboard | dashboard.yourdomain.com |
| [Linkding](https://github.com/sissbruecker/linkding) | Bookmark manager | links.yourdomain.com |
| [Stirling PDF](https://stirlingtools.com) | PDF tools | pdf.yourdomain.com |
| [Dozzle](https://dozzle.dev) | Container log viewer & manager | dozzle.yourdomain.com |
| [Watchtower](https://containrrr.dev/watchtower) | Auto container updates (04:00 daily) | — |

## Networking

- **Tunnel**: [Pangolin](https://github.com/fosrl/pangolin) (WireGuard-based) — Pi connects outbound to VPS, no firewall rules needed at home
- **DNS**: Wildcard `*.yourdomain.com` → VPS public IP (Cloudflare, proxy OFF)
- **SSL**: Let's Encrypt via Traefik on VPS
- **Internal**: [Tailscale](https://tailscale.com) for cross-NAT communication (e.g. Beszel hub → Pi agent)

## Backups

Automated via cron + systemd timers using [rclone](https://rclone.org):

| Data | Schedule | Destination |
|------|----------|-------------|
| Immich photos | 03:00 daily | AWS S3 |
| Immich photos | 01:00 daily | Google Drive |
| Odoo DB + filestore | 02:00 daily | AWS S3 |
| AnythingLLM | 00:00 daily | AWS S3 |

Scripts: [`pi/rclone/`](./pi/rclone/)

## Repository Structure

```
.
├── pi/                         # Raspberry Pi 5 services
│   ├── immich/                 # Immich — instance 1
│   ├── immich-luis/            # Immich — instance 2
│   ├── odoo/                   # Odoo ERP + online shop
│   ├── kestra/                 # Workflow automation
│   ├── beszel-agent/           # Metrics agent
│   ├── watchtower/             # Auto-updater
│   ├── rclone/                 # Backup scripts
│   └── tools/
│       ├── linkding/           # (unused on Pi, runs on VPS)
│       └── stirling-pdf/       # (unused on Pi, runs on VPS)
│
├── vps/                        # VPS services
│   ├── beszel-hub/             # Metrics dashboard hub
│   ├── beszel-agent/           # VPS metrics agent
│   ├── homepage/               # Dashboard + config
│   ├── linkding/               # Bookmarks
│   ├── stirling-pdf/           # PDF tools
│   ├── uptime-kuma/            # Uptime monitoring
│   ├── dozzle/                 # Container manager
│   └── watchtower/             # Auto-updater
│
├── INFRASTRUCTURE.md           # Full infrastructure documentation
├── README.md
└── LICENSE
```

## Getting Started

Each service has a `docker-compose.yml` and a `.env.example`. To deploy:

```bash
cp .env.example .env
# Edit .env with your values
docker compose up -d
```

### Expose a Pi service publicly

1. Install [Pangolin](https://github.com/fosrl/pangolin) on your VPS and [Newt](https://github.com/fosrl/newt) on your Pi
2. Open Pangolin dashboard → Sites → your site → **Add Resource**
3. Set subdomain and target: `http://localhost:PORT`
4. SSL certificate is issued automatically via Traefik + Let's Encrypt

### Expose a VPS-local service

1. Connect the container to the Pangolin Docker network:
   ```bash
   docker network connect pangolin <container-name>
   ```
2. Add a router + service entry to `/root/config/traefik/dynamic_config.yml`
3. Traefik hot-reloads automatically — no restart needed

## Security

- No ports open at home — all traffic routed via WireGuard tunnel
- fail2ban on VPS (SSH: 3 failed attempts → 24h ban)
- All credentials in `.env` files (never hardcoded in `docker-compose.yml`)
- Cloudflare DNS proxy OFF on all records

## License

MIT — see [LICENSE](./LICENSE)
