# TypeShield (AGPL-3.0)

> **Please note that I created this for my own personal use. I will not be maintaining or updating this code unless I need to make edits for myself. If you want a feature please fork the code and do whatever you need with it as allowable under the license.**

**TypeShield** blocks trackpad/mouse input for a brief window after each keypress to prevent stray palm touches while typing.  
Apple Silicon native (M1–M4), macOS 13+.

## Features
- Blocks clicks, drags, (optionally) scroll
- Tunable **block** and **grace** windows
- Simple **CLI**; optional LaunchAgent for auto-start at login
- Handy `typeshieldctl` tool for start/stop/restart/status/logs/edit
- Minimal **Xcode project** included for folks who prefer Xcode over SwiftPM.

## Build (SwiftPM)
```bash
swift build -c release
./.build/release/TypeShield --help
```

## Build (Xcode)
1. Open `TypeShield.xcodeproj` in Xcode 15+.
2. Select the **TypeShield** scheme.
3. Product → **Build** (⌘B) or **Run** (⌘R).
   - Executable output: `DerivedData/.../Build/Products/Debug/TypeShield`

## Install binary
```bash
sudo cp ./.build/release/TypeShield /usr/local/bin/typeshield
```

## Run
```bash
typeshield --block-ms 275 --grace-ms 40
# add --allow-scroll to allow scroll events during the block window
# add --verbose for debug output
```

## Flags
- `--block-ms <n>` (default 300)
- `--grace-ms <n>` (default 30)
- `--allow-scroll` (omit to block scrolling)
- `--verbose` | `-v`
- `--help` | `-h`
- `--version`

## Launch at login (optional)
```bash
mkdir -p ~/Library/LaunchAgents
cp Resources/com.typeshield.agent.plist ~/Library/LaunchAgents/
launchctl load -w ~/Library/LaunchAgents/com.typeshield.agent.plist
```

Edit defaults by changing `ProgramArguments` in the plist and reloading:
```bash
launchctl unload ~/Library/LaunchAgents/com.typeshield.agent.plist
launchctl load -w ~/Library/LaunchAgents/com.typeshield.agent.plist
```

## Control script
Install the helper script:
```bash
sudo cp scripts/typeshieldctl /usr/local/bin/typeshieldctl
sudo chmod +x /usr/local/bin/typeshieldctl
```

Usage:
```bash
typeshieldctl start|stop|restart|status|logs|edit|path
```

The `edit` command opens the plist in TextEdit and **auto-restarts** the agent after you save & close (if it was running).

## Recommended defaults (fast typists, 80–100 WPM)
```bash
typeshield --block-ms 275 --grace-ms 40
```

## Permissions
On first run, approve **System Settings → Privacy & Security → Input Monitoring** for the terminal or the binary path.

## License
SPDX-License-Identifier: AGPL-3.0-only  
© 2025 Eric Crescimano and contributors.

This program is free software: you can redistribute it and/or modify it under the terms of the **GNU Affero General Public License v3.0**.  
See [`LICENSE`](LICENSE) for the full license text.

## Optional resilience helpers

If you find TypeShield stops working after sleep and wake, or you want an aggressive self-healing setup, see `extras/docs/README-EXTRAS.md` and run:

```bash
./extras/install.sh
```

To remove the helpers:

```bash
./extras/uninstall.sh
```

