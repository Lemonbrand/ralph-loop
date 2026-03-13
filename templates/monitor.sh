#!/bin/bash
# Ralph Monitor - Voice notifications for phase gates, blockers, and completion
# Run via launchd (every 120 seconds) or manually: watch -n 120 ./monitor.sh

PROGRESS="$(dirname "$0")/progress.txt"
STATE_FILE="$(dirname "$0")/.monitor-state"

# Nothing to monitor if progress file doesn't exist
if [ ! -f "$PROGRESS" ]; then
  exit 0
fi

# Read last announced state
LAST_STATE=$(cat "$STATE_FILE" 2>/dev/null || echo "")

# Check for phase gate
if grep -q "PHASE_GATE" "$PROGRESS" 2>/dev/null; then
  CURRENT="phase_gate"
  if [ "$LAST_STATE" != "$CURRENT" ]; then
    say "Ralph hit a phase gate. Needs your review."
    echo "$CURRENT" > "$STATE_FILE"
  fi
  exit 0
fi

# Check for completion
if grep -q "COMPLETE" "$PROGRESS" 2>/dev/null; then
  CURRENT="complete"
  if [ "$LAST_STATE" != "$CURRENT" ]; then
    say "Ralph loop complete."
    echo "$CURRENT" > "$STATE_FILE"
  fi
  exit 0
fi

# Check for blocked
if grep -qi "blocked" "$PROGRESS" 2>/dev/null; then
  CURRENT="blocked"
  if [ "$LAST_STATE" != "$CURRENT" ]; then
    say "Ralph is blocked. Check progress."
    echo "$CURRENT" > "$STATE_FILE"
  fi
  exit 0
fi
