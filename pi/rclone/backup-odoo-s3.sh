#!/usr/bin/env bash
set -euo pipefail

COMPOSE_DIR="/home/<user>/server/odoo-moliendaquindiana"
BACKUP_DIR="$COMPOSE_DIR/backups"
LOG_FILE="/home/<user>/server/rclone/logs/odoo-backup.log"
S3_DST="s3-remote:<your-s3-bucket>/backups/odoo-moliendaquindiana"

mkdir -p "$BACKUP_DIR" "$(dirname "$LOG_FILE")"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "=== Starting Odoo Molienda Quindiana backup ==="

# Load env vars
set -a
# shellcheck source=/dev/null
source "$COMPOSE_DIR/.env"
set +a

# 1. DB dump
log "Dumping PostgreSQL database..."
DB_CONTAINER=$(docker compose -f "$COMPOSE_DIR/docker-compose.yml" ps -q db)
docker exec "$DB_CONTAINER" pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
  | gzip > "$BACKUP_DIR/db.sql.gz"
log "DB dump done: $(du -sh "$BACKUP_DIR/db.sql.gz" | cut -f1)"

# 2. Filestore backup
log "Backing up Odoo filestore..."
docker run --rm \
  -v odoo-moliendaquindiana_odoo-web-data:/from:ro \
  alpine sh -c "cd /from && tar czf - ." > "$BACKUP_DIR/filestore.tgz"
log "Filestore backup done: $(du -sh "$BACKUP_DIR/filestore.tgz" | cut -f1)"

# 3. Sync backups to S3
log "Syncing backups to S3..."
rclone sync "$BACKUP_DIR" "$S3_DST" \
  --transfers 4 \
  --s3-chunk-size 32M \
  --retries 3 \
  --log-file "$LOG_FILE" \
  --log-level INFO

log "=== Odoo backup completed successfully ==="
