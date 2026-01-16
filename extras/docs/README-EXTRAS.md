# TypeShield extras (optional)

These helpers are optional. They sit outside the main TypeShield binary and are intended to improve reliability across sleep and wake cycles.

## What is included

1) com.typeshield.autorestart-smart
- Runs every 5 seconds while you are logged in
- Exits quietly unless it detects a problem
- If TypeShield is missing or not loaded, it does nothing
- Rate-limits restarts to once per 60 seconds

2) com.typeshield.onwake
- Restarts TypeShield when loaded (login)
- Some macOS versions also run LaunchAgents after sleep and wake cycles, but behavior can vary.
- If you want the most reliable wake handling, consider a small wake watcher process that listens for didWake notifications.

## Install

From the repo root:

```bash
./extras/install.sh
```

## Uninstall

```bash
./extras/uninstall.sh
```

## Logs

- /tmp/ts-smart.log and /tmp/ts-smart.err
- /tmp/ts-onwake.log and /tmp/ts-onwake.err
