#!/bin/bash

# Script to sync local directory to S3 using rclone
DATE=$(date '+%Y-%m-%d %H:%M:%S')
echo "[$DATE] Starting sync" >> /home/<user>/server/rclone/rclone-sync.log

# Run the sync anythingLLM
rclone sync /home/<user>/anythingllm s3-remote:<your-s3-bucket>/ai/anythingllm \
  --progress \
  --stats 30s \
  --s3-chunk-size 32M \
  --retries 3 \
  --log-file /home/<user>/server/rclone/rclone-sync.log \
  --log-level INFO




EXIT_CODE=$?
DATE=$(date '+%Y-%m-%d %H:%M:%S')
if [ $EXIT_CODE -eq 0 ]; then
  echo "[$DATE] Sync completed successfully" >> /home/<user>/server/rclone/rclone-sync.log
else
  echo "[$DATE] Sync failed with exit code $EXIT_CODE" >> /home/<user>/server/rclone/rclone-sync.log
fi

exit $EXIT_CODE
