#!/bin/bash
set -euo pipefail

echo "TypeShield extras installer"
echo "This installs optional resilience helpers into your user account."

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_SRC="$ROOT_DIR/scripts"
AGENTS_SRC="$ROOT_DIR/launchagents"

SCRIPTS_DST="$HOME/Library/Scripts"
AGENTS_DST="$HOME/Library/LaunchAgents"

mkdir -p "$SCRIPTS_DST" "$AGENTS_DST"

install -m 755 "$SCRIPTS_SRC/typeshield-auto-restart.sh" "$SCRIPTS_DST/typeshield-auto-restart.sh"
install -m 755 "$SCRIPTS_SRC/typeshield-on-wake.sh" "$SCRIPTS_DST/typeshield-on-wake.sh"

# Copy plists and substitute __HOME__
for p in "$AGENTS_SRC"/com.typeshield.*.plist; do
  name="$(basename "$p")"
  out="$AGENTS_DST/$name"
  sed "s#__HOME__#$HOME#g" "$p" > "$out"
  chmod 644 "$out"
done

# Load agents using modern launchctl
UID="$(id -u)"
for label in com.typeshield.autorestart-smart com.typeshield.onwake; do
  plist="$AGENTS_DST/$label.plist"
  if launchctl print "gui/$UID/$label" >/dev/null 2>&1; then
    launchctl bootout "gui/$UID" "$plist" >/dev/null 2>&1 || true
  fi
  launchctl bootstrap "gui/$UID" "$plist"
  launchctl enable "gui/$UID/$label"
  launchctl kickstart -k "gui/$UID/$label" >/dev/null 2>&1 || true
done

echo "Installed:"
echo "  - com.typeshield.autorestart-smart (runs every 5 seconds, restarts only when needed)"
echo "  - com.typeshield.onwake (restarts TypeShield at login and after wake cycles, depending on macOS)"
echo ""
echo "Logs:"
echo "  /tmp/ts-smart.log  /tmp/ts-smart.err"
echo "  /tmp/ts-onwake.log /tmp/ts-onwake.err"
