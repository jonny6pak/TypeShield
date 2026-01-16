#!/bin/bash
set -euo pipefail

TSCTL="/usr/local/bin/typeshieldctl"
TS_LABEL="com.typeshield.agent"

if launchctl print "gui/$(id -u)/$TS_LABEL" >/dev/null 2>&1; then
  "$TSCTL" restart >/dev/null 2>&1 || true
fi

exit 0
