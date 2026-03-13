#!/usr/bin/env bash
set -euo pipefail

SRC="/media/<user>/storage-disk/immich"
DST="gdrive-remote:backups/immich"

# carpeta de logs
mkdir -p "$HOME/server/rclone/logs"

exec nice -n 10 ionice -c2 -n7 \
rclone sync "$SRC" "$DST/current" \
  --filter-from "$HOME/server/immich/immich.rclone-filter" \
  --transfers 4 --checkers 8 \
  --drive-chunk-size 128M \
  --stats 30s \
  --log-file "$HOME/server/rclone/logs/immich-gdrive.log" \
  --log-level INFO
