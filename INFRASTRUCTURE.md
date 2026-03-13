# Infrastructure Report
_Last updated: 2026-03-05_

---

## Overview

Two-node homelab setup:
- **Pi** — Raspberry Pi 5 at home (no open ports). Runs data-heavy services.
- **VPS** — Cloud VM (<vps-public-ip>). Runs lightweight/monitoring services and acts as public entry point.

Internet traffic enters via the VPS (Traefik + Pangolin), then tunnels to the Pi via WireGuard (Gerbil/Newt) for Pi-hosted services.

```
Internet
   │
   ▼
VPS (<vps-public-ip>)
 ├── Traefik (SSL termination, routing)
 ├── Pangolin (tunnel management dashboard)
 └── Gerbil (WireGuard manager)
        │
        │  WireGuard tunnel
        ▼
Pi (home, no open ports)
 └── Newt (tunnel client, systemd service)
        │
        ▼
   Pi Services (Immich, Odoo, etc.)
```

Internal monitoring uses **Tailscale**:
- VPS Tailscale IP: `<tailscale-ip-vps>`
- Pi Tailscale IP:  `<tailscale-ip-pi>`

Domain: `yourdomain.com` (Cloudflare DNS, proxy OFF on all records)

---

## Node 1 — Raspberry Pi 5

| Property     | Value                              |
|--------------|------------------------------------|
| Hardware     | Raspberry Pi 5 Model B Rev 1.0     |
| OS           | Debian GNU/Linux 12 (Bookworm)     |
| Architecture | ARM64                              |
| CPU          | 4 cores (Cortex-A76)               |
| RAM          | 8 GB total / ~3.2 GB available     |
| Swap         | 4 GB swapfile at `/swapfile` (NVMe) |
| NVMe         | 938 GB — 401 GB used (46%)         |
| External HDD | 954 GB — 932 GB used (98%) at `/media/<user>/storage-disk` |
| Tailscale IP | `<tailscale-ip-pi>`                   |

### Docker Services (Pi)

| Container | Image | Port | Config | Notes |
|-----------|-------|------|--------|-------|
| `immich_server` | `immich-server:release` | 2283 | `.env` | Felipe's photo library |
| `immich_machine_learning` | `immich-machine-learning:release` | — | `.env` | ML for Felipe's Immich |
| `immich_postgres` | `tensorchord/pgvecto-rs:pg14` | — | `.env` | DB for Felipe's Immich |
| `immich_redis` | `redis:6.2-alpine` | — | — | Cache for Felipe's Immich |
| `immich_server-luis` | `immich-server:release` | 2284 | `.env` | Luis's photo library (~52 GB) |
| `immich_machine_learning-luis` | `immich-machine-learning:release` | — | `.env` | ML for Luis's Immich |
| `immich_postgres-luis` | `tensorchord/pgvecto-rs:pg14` | — | `.env` | DB for Luis's Immich |
| `immich_redis-luis` | `redis:6.2-alpine` | — | — | Cache for Luis's Immich |
| `odoo-moliendaquindiana-web-1` | `odoo:18.0` | 8069 | `.env` | Public online shop (<client-project>) |
| `odoo-moliendaquindiana-db-1` | `postgres:17` | 5432 (localhost) | `.env` | Odoo DB |
| `nifty_mestorf2` | `mintplexlabs/anythingllm` | 3001 | Dokploy | AI assistant |
| `dokploy` | `dokploy/dokploy:v0.28.3` | 3000 | — | Container management PaaS |
| `dokploy-postgres` | `postgres:16` | — | — | Dokploy DB |
| `dokploy-redis` | `redis:7` | — | — | Dokploy cache |
| `dokploy-traefik` | `traefik:v3.6.7` | 80, 443 | — | Dokploy's internal proxy |
| `beszel-agent` | `henrygd/beszel-agent` | 45876 | `.env` | Reports to Beszel hub on VPS via Tailscale |
| `watchtower` | `containrrr/watchtower` | — | `.env` | Auto-updates containers daily at 04:00 |

### Native Services (Pi)

| Service | Port | Notes |
|---------|------|-------|
| Pi-hole (pihole-FTL) | 8082 | DNS-level ad blocker, moved from 80 to free it for Traefik |
| Newt | — | Systemd service, WireGuard tunnel client → pangolin.yourdomain.com |
| Tailscale | — | Systemd service, used for Beszel hub→agent communication |

### Public Domains (Pi → Pangolin → VPS)

| Domain | Service | Port |
|--------|---------|------|
| `immich.yourdomain.com` | Immich (Felipe) | 2283 |
| `immich-user2.yourdomain.com` | Immich (Luis) | 2284 |
| `odoo.yourdomain.com` | Odoo shop | 8069 |
| `llm.yourdomain.com` | AnythingLLM | 3001 |

### Service Paths (Pi)

| Service | Path | Has .env |
|---------|------|----------|
| Immich (Felipe) | `/home/<user>/server/immich/` | Yes |
| Immich (Luis) | `/home/<user>/server/immich-user2/` | Yes |
| Odoo | `/home/<user>/server/odoo-moliendaquindiana/` | Yes |
| AnythingLLM | (managed by Dokploy) | — |
| Beszel agent | `/home/<user>/server/beszel/agent/` | Yes |
| Watchtower | `/home/<user>/server/watchtower/` | Yes |
| Stirling PDF (unused) | `/home/<user>/server/tools/stirling-pdf/` | Yes |
| Linkding (unused) | `/home/<user>/server/tools/linkding/` | Yes |
| Kestra (stopped) | `/home/<user>/server/kestra/` | Yes |

### Backups (Pi → Cloud)

All scheduled via cron and systemd timers:

| Job | Schedule | Destination | Script |
|-----|----------|-------------|--------|
| Immich → S3 | 03:00 daily (systemd timer) | `s3-remote:<your-s3-bucket>/backups/immich` | `server/rclone/sync-immich-s3.sh` |
| Immich → Google Drive | 01:00 daily (cron) | `gdrive-remote:backups/immich` | `server/rclone/sync-immich-gdrive.sh` |
| Odoo → S3 | 02:00 daily (cron) | `s3-remote:<your-s3-bucket>/backups/odoo-moliendaquindiana` | `server/rclone/backup-odoo-s3.sh` |
| AnythingLLM → S3 | 00:00 daily (cron) | S3 | `server/rclone/sync-anyllm-s3.sh` |

Logs: `~/server/rclone/logs/`

---

## Node 2 — VPS

| Property     | Value                                        |
|--------------|----------------------------------------------|
| Provider     | Cloud VPS (AWS-style, paid)                  |
| Public IP    | `<vps-public-ip>`                            |
| OS           | Ubuntu 22.04.1 LTS (Jammy Jellyfish)         |
| Architecture | x86_64                                       |
| CPU          | 1 vCPU (Intel Xeon Skylake)                  |
| RAM          | 2 GB total / 2 GB swap                       |
| Disk         | 50 GB — 14 GB used (27%)                     |
| Tailscale IP | `<tailscale-ip-vps>`                             |

### Docker Services (VPS)

| Container | Image | Port (host) | RAM Usage | Config | Notes |
|-----------|-------|-------------|-----------|--------|-------|
| `pangolin` | `fosrl/pangolin:1.16.2` | — | ~257 MB | — | Tunnel management dashboard |
| `gerbil` | `fosrl/gerbil:1.3.0` | 80, 443, 51820/udp, 21820/udp | ~5 MB | — | WireGuard manager |
| `traefik` | `traefik:v3.6` | 80, 443 | ~31 MB | — | Reverse proxy + SSL (Let's Encrypt) |
| `uptime-kuma` | `louislam/uptime-kuma:1` | 3002 | ~101 MB | — | Uptime monitoring |
| `beszel` | `henrygd/beszel` | 8090 | ~19 MB | — | System metrics dashboard (hub) |
| `beszel-agent` | `henrygd/beszel-agent` | 45876 | ~6 MB | `.env` | Local VPS agent |
| `homepage` | `ghcr.io/gethomepage/homepage:latest` | 3003 | ~71 MB | `.env` | Services dashboard |
| `linkding` | `sissbruecker/linkding:latest` | 9090 | ~39 MB | — | Bookmark manager |
| `stirling-pdf` | `stirlingtools/stirling-pdf:latest` | 8081 | ~725 MB | `.env` | PDF tools |
| `dozzle` | `amir20/dozzle:latest` | — | ~10 MB | `.env` | Container log viewer + start/stop |
| `watchtower` | `containrrr/watchtower` | — | ~10 MB | `.env` | Auto-updates containers daily at 04:00 |

> **Note:** Stirling PDF is memory-heavy (~725 MB). On a 2 GB VPS this leaves little headroom.

### Security (VPS)

- **fail2ban** — installed and active. SSH jail: 3 failed attempts → 24h ban.
  - Config: `/etc/fail2ban/jail.local`
  - Check status: `fail2ban-client status sshd`

### Docker Networks (VPS)

All VPS-local services that need Traefik routing must be connected to the `pangolin` Docker network:
```bash
docker network connect pangolin <container-name>
```

### Public Domains (VPS-local → Traefik)

| Domain | Service | Container port |
|--------|---------|----------------|
| `pangolin.yourdomain.com` | Pangolin dashboard | 3002 / 3000 |
| `uptime.yourdomain.com` | Uptime Kuma | 3001 |
| `beszel.yourdomain.com` | Beszel hub | 8090 |
| `dashboard.yourdomain.com` | Homepage | 3000 |
| `links.yourdomain.com` | Linkding | 9090 |
| `pdf.yourdomain.com` | Stirling PDF | 8080 |
| `dozzle.yourdomain.com` | Dozzle | 8080 |

### Service Paths (VPS)

| Service | Path | Has .env |
|---------|------|----------|
| Pangolin stack | `/root/config/` | — |
| Traefik dynamic config | `/root/config/traefik/dynamic_config.yml` | — |
| Uptime Kuma | `/root/server/uptime-kuma/` | — |
| Beszel hub | `/root/server/beszel-hub/` | — |
| Beszel agent | `/root/server/beszel/` | Yes |
| Homepage | `/root/server/homepage/` | Yes |
| Linkding | `/root/server/linkding/` | — |
| Stirling PDF | `/root/server/stirling-pdf/` | Yes |
| Dozzle | `/root/server/dozzle/` | Yes |
| Watchtower | `/root/server/watchtower/` | Yes |

### Firewall / Open Ports (VPS)

| Port | Protocol | Purpose |
|------|----------|---------|
| 22 | TCP | SSH |
| 80 | TCP | HTTP (Let's Encrypt ACME challenge) |
| 443 | TCP | HTTPS |
| 45876 | TCP | Beszel agent |
| 51820 | UDP | WireGuard (Pangolin) |
| 21820 | UDP | WireGuard (Pangolin alt) |

---

## Networking & Routing

### DNS
All domains point to `<vps-public-ip>` (VPS public IP).
Wildcard `*.yourdomain.com` → VPS IP covers all subdomains.
Cloudflare proxy is **OFF** (grey cloud) on all records.

### How to expose a Pi service

1. Pangolin dashboard → Sites → **home-pi** → Add Resource
2. Subdomain: e.g. `myapp`, Target: `http://localhost:PORT`
3. DNS already covered by wildcard

### How to expose a VPS-local service

1. Connect container to Pangolin network:
   ```bash
   docker network connect pangolin <container>
   ```
2. Add router + service to `/root/config/traefik/dynamic_config.yml`
   _(always rewrite the full file, never append)_
3. Traefik hot-reloads automatically — no restart needed

### Beszel Hub → Agent Communication

Beszel hub on VPS connects to Pi agent via Tailscale:
- Pi agent listens on port 45876
- Hub connects to `<tailscale-ip-pi>:45876` (Tailscale IP)
- VPS agent is on `localhost:45876`

---

## Software Versions

| Software | Version |
|----------|---------|
| Pangolin | 1.16.2 |
| Gerbil | 1.3.0 |
| Traefik (VPS) | 3.6 |
| Newt (Pi) | 1.10.1 |
| Odoo | 18.0 |
| Immich | latest (release tag) |

---

## Known Issues / Notes

- **External HDD nearly full**: `/media/<user>/storage-disk` at 98% (932/954 GB). Stores Immich (Felipe) photos.
- **VPS RAM tight**: Stirling PDF alone uses ~725 MB on a 2 GB machine. Swap (2 GB) is configured.
- **Portainer & Dokploy removed** from Pi. Dozzle used on VPS for container management.
- **Kestra** installed on Pi (`/home/<user>/server/kestra/`) but not running.
- **AnythingLLM** runs standalone, container name: `anythingllm`, data at `/home/<user>/anythingllm/`.
- **Dozzle** user config at `/root/server/dozzle/data/users.yml` — regenerate with `docker run --rm amir20/dozzle:latest generate <user> --password <pass> --name "<name>"`.

---

## Node 3 — Mini PC

A third machine running Home Assistant OS with additional services, also tunneled via Pangolin.

### Public Domains (Mini PC → Pangolin → VPS)

| Domain | Service | Notes |
|--------|---------|-------|
| `home.yourdomain.com` | Home Assistant | Home automation |
| `proxmox.yourdomain.com` | Proxmox | Hypervisor / VM manager |
| `nextcloud_old.yourdomain.com` | Nextcloud | File storage (legacy) |
