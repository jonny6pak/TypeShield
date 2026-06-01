#!/bin/bash
set -euo pipefail

echo "TypeShield extras installer"
echo "This installs optional resilience helpers into your user account."

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_SRC="$ROOT_DIR/extras/scripts"
AGENTS_SRC="$ROOT_DIR/extras/launchagents"

# Backward-compatible fallback if called from inside extras/
if [ ! -d "$SCRIPTS_SRC" ]; then
  ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  SCRIPTS_SRC="$ROOT_DIR/scripts"
  AGENTS_SRC="$ROOT_DIR/launchagents"
fi

SCRIPTS_DST="$HOME/Library/Scripts"
AGENTS_DST="$HOME/Library/LaunchAgents"

mkdir -p "$SCRIPTS_DST" "$AGENTS_DST" "$HOME/Library/Logs"

install -m 755 "$SCRIPTS_SRC/typeshield-auto-restart.sh" "$SCRIPTS_DST/typeshield-auto-restart.sh"
install -m 755 "$SCRIPTS_SRC/typeshield-on-wake.sh" "$SCRIPTS_DST/typeshield-on-wake.sh"

# Copy helper plists and substitute absolute home path.
for p in "$AGENTS_SRC"/com.typeshield.*.plist; do
  name="$(basename "$p")"
  out="$AGENTS_DST/$name"
  sed "s#__HOME__#$HOME#g" "$p" > "$out"
  chmod 644 "$out"
done

UID_NUM="$(id -u)"

for label in com.typeshield.autorestart-smart com.typeshield.onwake; do
  plist="$AGENTS_DST/$label.plist"
  launchctl bootout "gui/$UID_NUM" "$plist" >/dev/null 2>&1 || true
  launchctl bootstrap "gui/$UID_NUM" "$plist"
  launchctl enable "gui/$UID_NUM/$label"
  launchctl kickstart -k "gui/$UID_NUM/$label" >/dev/null 2>&1 || true
done

echo "Installed optional helpers:"
echo "  - com.typeshield.autorestart-smart"
echo "  - com.typeshield.onwake"
echo ""
echo "Core TypeShield LaunchAgent is not modified by this installer."
echo "Install the core agent separately from Resources/com.typeshield.agent.plist after replacing __HOME__."
