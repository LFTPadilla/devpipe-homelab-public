# Odoo 18 - Molienda Quindiana

Odoo 18 + PostgreSQL 17 via Docker Compose.

## Structure

```
odoo-moliendaquindiana/
├── docker-compose.yml     # Services definition
├── .env                   # Credentials (never commit)
├── config/odoo.conf       # Odoo configuration
├── addons/                # Custom addons (bind-mounted)
│   ├── account-financial-reporting/
│   ├── reporting-engine/
│   ├── server-tools/
│   └── server-ux/
└── backups/               # Local backup staging (synced to S3)
    ├── db.sql.gz
    └── filestore.tgz
```

Docker **named volumes** hold live data:
- `odoo-moliendaquindiana_odoo-web-data` → Odoo filestore (`/var/lib/odoo`)
- `odoo-moliendaquindiana_odoo-db-data` → PostgreSQL data

## Quick Start

```bash
cp .env.example .env   # fill in credentials
docker compose up -d
```

Access: http://localhost:8069

## Environment Variables (.env)

```
POSTGRES_DB=postgres_odoo
POSTGRES_USER=odoo
POSTGRES_PASSWORD=<strong-password>
PGDATA=/var/lib/postgresql/data/pgdata
```

> **Security**: `admin_passwd` in `config/odoo.conf` is the Odoo master password — change it from `admin` before exposing publicly.

## Backup

Automated daily backup at 02:00 via cron → `/home/felipe/server/rclone/backup-odoo-s3.sh`

What gets backed up:
- PostgreSQL dump: `backups/db.sql.gz`
- Odoo filestore: `backups/filestore.tgz`
- Synced to: `s3-remote:<your-s3-bucket>/backups/<odoo-project>`

Manual backup:
```bash
/home/felipe/server/rclone/backup-odoo-s3.sh
```

## Restore on a New Server

### 1. Prerequisites
```bash
# Install Docker + Docker Compose
# Install rclone (configured with s3-remote)
```

### 2. Copy project files
```bash
git clone / scp the odoo-moliendaquindiana/ directory
cd odoo-moliendaquindiana
# Ensure .env is present with correct credentials
```

### 3. Start containers (empty DB)
```bash
docker compose up -d
# Wait for containers to be healthy
docker compose ps
```

### 4. Download backups from S3
```bash
rclone copy s3-remote:<your-s3-bucket>/backups/<odoo-project>/db.sql.gz backups/
rclone copy s3-remote:<your-s3-bucket>/backups/<odoo-project>/filestore.tgz backups/
```

### 5. Restore PostgreSQL database
```bash
# Stop odoo web to avoid connections during restore
docker compose stop web

# Drop and recreate the database
docker compose exec db psql -U odoo -c "DROP DATABASE IF EXISTS postgres_odoo;"
docker compose exec db psql -U odoo -c "CREATE DATABASE postgres_odoo;"

# Restore
gunzip -c backups/db.sql.gz | docker exec -i $(docker compose ps -q db) psql -U odoo -d postgres_odoo
```

### 6. Restore Odoo filestore
```bash
docker run --rm -i \
  -v odoo-moliendaquindiana_odoo-web-data:/to \
  alpine sh -c "cd /to && tar xzf -" < backups/filestore.tgz
```

### 7. Start Odoo
```bash
docker compose start web
docker compose logs -f web
```

## Useful Commands

```bash
# Logs
docker compose logs -f web
docker compose logs -f db

# Restart
docker compose restart web

# Access DB
docker compose exec db psql -U odoo -d postgres_odoo

# Shell into Odoo
docker compose exec web bash

# Update Odoo image
docker compose pull web && docker compose up -d --force-recreate web
```
