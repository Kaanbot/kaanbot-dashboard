#!/bin/bash

# fetch-data.sh - Generate status.json for KaanBot Dashboard

WORKSPACE="/root/.openclaw/workspace"
OUTPUT_DIR="/root/.openclaw/workspace/kaanbot-dashboard/data"
mkdir -p "$OUTPUT_DIR"

# Get system info
GATEWAY_PID=$(pgrep -f "openclaw-gateway" | head -1)
if [ -n "$GATEWAY_PID" ]; then
  UPTIME_SECS=$(ps -o etimes= -p "$GATEWAY_PID" 2>/dev/null | tr -d ' ' || echo "0")
  DAYS=$((UPTIME_SECS / 86400))
  HOURS=$(( (UPTIME_SECS % 86400) / 3600 ))
  UPTIME="${DAYS}d ${HOURS}h"
else
  UPTIME="Unknown"
fi

# Count memory files
MEMORY_COUNT=$(ls -1 "$WORKSPACE/memory/"*.md 2>/dev/null | wc -l)
MEMORY_SIZE=$(du -sb "$WORKSPACE/memory" 2>/dev/null | cut -f1 || echo "0")

# Generate recent memory list
RECENT_MEMORY=""
for days_ago in 0 1 2; do
  DATE=$(date -d "$days_ago days ago" -u +"%Y-%m-%d" 2>/dev/null || date -u -d "-$days_ago days" +"%Y-%m-%d")
  if [ -f "$WORKSPACE/memory/$DATE.md" ]; then
    SIZE=$(wc -c < "$WORKSPACE/memory/$DATE.md")
    RECENT_MEMORY+="{\"date\": \"$DATE\", \"size\": $SIZE},"
  fi
done
# Remove trailing comma
RECENT_MEMORY="${RECENT_MEMORY%,}"

# Generate activity timeline (commits)
cd "$WORKSPACE"
ACTIVITY=$(git log --format='%h|%s|%ar' -5 2>/dev/null | while IFS='|' read -r hash msg time; do
  # Escape quotes in commit message
  MSG_ESCAPED=$(echo "$msg" | sed 's/"/\\"/g')
  echo "{\"type\": \"commit\", \"message\": \"$MSG_ESCAPED\", \"time\": \"$time\"},"
done)
ACTIVITY="${ACTIVITY%,}"

# Generate cron jobs list
CRON_JOBS='{"name": "daily-briefing", "schedule": "0 7 * * *", "status": "enabled"},
{"name": "weekly-surprise", "schedule": "0 9 * * 5", "status": "enabled"},
{"name": "project-health-check", "schedule": "0 */6 * * *", "status": "enabled"},
{"name": "memory-maintenance", "schedule": "0 3 * * *", "status": "enabled"}'

# Generate channels list
CHANNELS='{"name": "Telegram", "status": "connected"},
{"name": "WhatsApp", "status": "connected"},
{"name": "Discord", "status": "connected"}'

# Build JSON
cat > "$OUTPUT_DIR/status.json" << EOF
{
  "system": {
    "version": "2026.2.19-2",
    "model": "glm-4.7",
    "uptime": "$UPTIME",
    "updateAvailable": true
  },
  "channels": [
    $CHANNELS
  ],
  "memory": {
    "files": $MEMORY_COUNT,
    "totalSize": $MEMORY_SIZE,
    "chunks": 0,
    "dirty": false
  },
  "sessions": [
    {"key": "main", "age": "active", "model": "glm-4.7", "tokens": "15k/205k (7%)"}
  ],
  "cronJobs": [
    $CRON_JOBS
  ],
  "activity": [
    $ACTIVITY
  ],
  "recentMemory": [
    $RECENT_MEMORY
  ],
  "lastUpdated": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

echo "✅ Status data generated: $OUTPUT_DIR/status.json"
