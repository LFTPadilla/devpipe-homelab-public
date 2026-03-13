#!/usr/bin/env bash
set -euo pipefail

SRC="/media/<user>/storage-disk/immich"
DST="s3-remote:<your-s3-bucket>/backups/immich"

# carpeta de logs
mkdir -p "$HOME/server/rclone/logs"

exec nice -n 10 ionice -c2 -n7 \
rclone sync "$SRC" "$DST/current" \
#  --backup-dir "$DST/deleted/$(date +%F)" \
  --filter-from "$HOME/server/immich/immich.rclone-filter" \
  --transfers 8 --checkers 16 --fast-list \
  --s3-server-side-encryption AES256 \
  --stats 30s \
  --log-file "$HOME/server/rclone/logs/immich.log" \
  --log-level INFO
