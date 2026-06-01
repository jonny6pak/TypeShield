# TypeShield (AGPL-3.0)

> **IT FINALLY WORKS!!!!  Read the Launch Agent 1.0.5 packaging fix for the relevent info to ensure you get this running properly on your system.  Please note that I created this for my own personal use using ChatGPT with human verification.  This was a project to help me learn Swift and get back into coding after decades of not writing anything (hence starting with ChatGPT).  While ChatGPT was able to get me started, ChatGPT did not create code that actually worked as intended.  I was able to reach a point where I could do some manual debugging and write actual modifications for versions 1.0.4 and 1.0.5 myself.  And behold, it works!  With that said, I will not be maintaining or updating this code unless I need to make edits for myself. If you want a feature please fork the code and do whatever you need with it as allowable under the license.  I hope someone finds this useful.**

**TypeShield** blocks trackpad/mouse input for a brief window after each keypress to prevent stray palm touches while typing.  
Apple Silicon native (M1–M4), macOS 13+.

## v1.0.4 cursor-lock mode

This version adds an optional `--lock-cursor` flag. This is more aggressive than `--freeze-cursor`.

When enabled, TypeShield saves the cursor position at the beginning of a typing suppression burst and repeatedly warps the cursor back to that position until the block window expires. This is intended for systems where pointer events are blocked and cursor association is frozen, but the visible cursor still drifts during palm drag.

Example:

```bash
typeshield --block-ms 600 --grace-ms 45 --lock-cursor --verbose
```

You may also combine it with `--freeze-cursor`:

```bash
typeshield --block-ms 600 --grace-ms 45 --freeze-cursor --lock-cursor --verbose
```

## v1.0.3 cursor-freeze mode

This version adds an optional `--freeze-cursor` flag. When enabled, TypeShield temporarily calls `CGAssociateMouseAndMouseCursorPosition(false)` during the suppression window and re-enables cursor association when the window expires. This is intended for systems where pointer events are being blocked but the visible cursor can still move during palm drags.

Example:

```bash
typeshield --block-ms 600 --grace-ms 45 --freeze-cursor --verbose
```

## v1.0.2 reliability fixes

This version includes several correctness fixes intended to improve palm-drag suppression:

- Keyboard and pointer taps both run at `.cghidEventTap` to avoid HID/session timing races.
- `markKeyNow()` captures the timestamp immediately and writes it synchronously.
- Only `keyDown` updates the typing timer; modifier-only `flagsChanged` events no longer extend the block window.
- Event pass-through now uses `Unmanaged.passUnretained(event)`.
- The watchdog only re-enables taps if they are actually disabled.

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
- `--freeze-cursor` (temporarily freezes cursor movement during suppression)
- `--lock-cursor` (actively pins cursor to its pre-typing position during suppression)
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


## v1.0.5 LaunchAgent packaging fix

This version keeps the v1.0.4 `--lock-cursor` behavior and fixes the LaunchAgent packaging/docs.

Important: `launchd` does **not** expand `$HOME` or `~` in `StandardOutPath` or `StandardErrorPath`.  
The LaunchAgent template in `Resources/com.typeshield.agent.plist` uses `__HOME__` as a placeholder. Use `scripts/install-launchagent` or replace `__HOME__` manually with your absolute home path.

## Current recommended settings

For the strongest palm-drag protection:

```bash
typeshield --block-ms 300 --grace-ms 45 --lock-cursor
```

For debugging:

```bash
typeshield --block-ms 300 --grace-ms 45 --lock-cursor --verbose
```

## Install the core LaunchAgent

After building and installing the binary:

```bash
swift build -c release
sudo cp .build/release/TypeShield /usr/local/bin/typeshield
sudo chmod +x /usr/local/bin/typeshield
```

Install the LaunchAgent:

```bash
scripts/install-launchagent
```

Verify:

```bash
launchctl print gui/$(id -u)/com.typeshield.agent | head -n 40
pgrep -af "/usr/local/bin/typeshield"
```

Uninstall the LaunchAgent:

```bash
scripts/uninstall-launchagent
```

## Optional resilience helpers

If TypeShield stops working after sleep/wake, optional helper agents are available:

```bash
extras/install.sh
```

Remove them:

```bash
extras/uninstall.sh
```

These helpers are optional. The core app only requires `com.typeshield.agent`.
