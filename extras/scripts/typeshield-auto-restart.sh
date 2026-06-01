#!/bin/bash
set -euo pipefail

TS_LABEL="com.typeshield.agent"
TS_PLIST="$HOME/Library/LaunchAgents/com.typeshield.agent.plist"
TS_BIN="/usr/local/bin/typeshield"
TSCTL="/usr/local/bin/typeshieldctl"

# Restart throttling: do not restart more often than every 60 seconds
STATE_DIR="$HOME/Library/Caches/TypeShield"
STAMP="$STATE_DIR/last_restart_epoch"
MIN_SECONDS_BETWEEN_RESTARTS=60

mkdir -p "$STATE_DIR"

now_epoch() { date +%s; }

can_restart_now() {
  local now last
  now="$(now_epoch)"
  if [ -f "$STAMP" ]; then
    last="$(cat "$STAMP" 2>/dev/null || echo 0)"
  else
    last=0
  fi
  if [ $((now - last)) -lt "$MIN_SECONDS_BETWEEN_RESTARTS" ]; then
    return 1
  fi
  return 0
}

mark_restarted() { now_epoch > "$STAMP"; }

# Essentials missing -> do nothing
[ -x "$TS_BIN" ] || exit 0
[ -x "$TSCTL" ] || exit 0
[ -f "$TS_PLIST" ] || exit 0

# If the TypeShield LaunchAgent is not loaded, do nothing
launchctl print "gui/$(id -u)/$TS_LABEL" >/dev/null 2>&1 || exit 0

# Detect running process by command path (more reliable than process name)
if ! pgrep -f "^${TS_BIN}($| )" >/dev/null 2>&1; then
  if can_restart_now; then
    "$TSCTL" restart >/dev/null 2>&1 || true
    mark_restarted
  fi
  exit 0
fi

# Optional: restart if we see tap disable events recently (from verbose logs)
ERRLOG="$HOME/Library/Logs/typeshield.err.log"
if [ -f "$ERRLOG" ]; then
  if tail -n 200 "$ERRLOG" | grep -Eqi "tapDisabledByTimeout|tapDisabledByUserInput"; then
    if can_restart_now; then
      "$TSCTL" restart >/dev/null 2>&1 || true
      mark_restarted
    fi
    exit 0
  fi
fi

exit 0
