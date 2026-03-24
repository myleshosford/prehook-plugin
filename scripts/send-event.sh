#!/bin/bash
# send-event.sh
# Unified hook script for all Claude Code lifecycle events.
# Forwards the full event JSON to prehook.ai API.
# PreToolUse runs synchronously to support allow/deny decisions.

INPUT=$(cat)
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

CONFIG_FILE="${HOME}/.prehook/config.json"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "prehook: config not found at $CONFIG_FILE — see README for setup" >&2
  exit 1
fi

API_URL=$(jq -r '.api_url // empty' "$CONFIG_FILE")
API_KEY=$(jq -r '.api_key // empty' "$CONFIG_FILE")

if [ -z "$API_URL" ] || [ -z "$API_KEY" ]; then
  echo "prehook: api_url and api_key must be set in $CONFIG_FILE" >&2
  exit 1
fi

# Allow env var overrides for local dev/testing
API_URL="${PREHOOK_API_URL:-$API_URL}"
API_KEY="${PREHOOK_API_KEY:-$API_KEY}"

# Forward entire input, adding event_type and timestamp
EVENT_TYPE=$(echo "$INPUT" | jq -r '.hook_event_name // empty')
PAYLOAD=$(echo "$INPUT" | jq -c '. + {event_type: .hook_event_name, timestamp: $ts}' --arg ts "$TIMESTAMP")

# Local debug log
LOG_DIR="${HOME}/.prehook/logs"
mkdir -p "$LOG_DIR"
echo "$TIMESTAMP | $PAYLOAD" >> "$LOG_DIR/events.log"

if [ "$EVENT_TYPE" = "PreToolUse" ]; then
  # Synchronous — wait for API decision
  RESPONSE=$(curl -sL --max-time 3 \
    -X POST "$API_URL" \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" 2>/dev/null) || true

  DECISION=$(echo "$RESPONSE" | jq -r '.decision // "allow"' 2>/dev/null)
  REASON=$(echo "$RESPONSE" | jq -r '.reason // "Blocked by prehook.ai"' 2>/dev/null)

  if [ "$DECISION" = "deny" ]; then
    echo "$REASON" >&2
    exit 2
  fi
  exit 0
else
  # Fire-and-forget for all other events
  (
    HTTP_CODE=$(curl -sL -o /dev/null -w "%{http_code}" \
      --max-time 3 \
      -X POST "$API_URL" \
      -H "Authorization: Bearer $API_KEY" \
      -H "Content-Type: application/json" \
      -d "$PAYLOAD")

    if [ "$HTTP_CODE" != "200" ] && [ "$HTTP_CODE" != "201" ]; then
      echo "$TIMESTAMP | HTTP $HTTP_CODE | $PAYLOAD" >> "$LOG_DIR/failed-events.log"
    fi
  ) &
  exit 0
fi
