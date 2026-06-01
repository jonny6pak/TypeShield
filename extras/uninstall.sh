#!/bin/bash
set -euo pipefail

echo "TypeShield extras uninstaller"

UID="$(id -u)"
AGENTS_DST="$HOME/Library/LaunchAgents"

for label in com.typeshield.autorestart-smart com.typeshield.onwake; do
  plist="$AGENTS_DST/$label.plist"
  if [ -f "$plist" ]; then
    launchctl bootout "gui/$UID" "$plist" >/dev/null 2>&1 || true
    rm -f "$plist"
  fi
done

rm -f "$HOME/Library/Scripts/typeshield-auto-restart.sh" \
      "$HOME/Library/Scripts/typeshield-on-wake.sh"

echo "Removed extras. TypeShield core agent is unchanged."
