# TypeShield (AGPL-3.0)

TypeShield is a lightweight macOS utility that prevents accidental trackpad movement, clicks, and drags while typing.

It works by monitoring keyboard activity at the HID level and temporarily suppressing pointer events immediately after a keystroke. This helps eliminate cursor jumps, accidental selections, and palm-drag issues common on large trackpads.

> **IT FINALLY WORKS!!!!  Please make sure you pay attention to the "Important Note" section of the README. I will most likely not update this code unless there's a real problem with the code or if I need edits for myself.  This project was a learning endevor for me.  If you notice problems with the actual code, I'm all about learning what I did wrong.  But if you want a feature or to further develop, please fork the code and do whatever you want with it as allowable under the license.  I hope someone finds this useful. 

## Features

* HID-level keyboard detection
* HID-level pointer suppression
* Configurable typing suppression window
* Optional cursor lock mode for aggressive palm-drag prevention
* Optional cursor freeze mode
* LaunchAgent support for automatic startup
* Sleep/wake recovery helpers
* Low resource usage
* No menu bar application required

## Requirements

* macOS 13 or later recommended
* Input Monitoring permission
* Accessibility permission may be required depending on configuration
* Apple Silicon and Intel Macs supported

## Installation

Build the project:

```bash
swift build -c release
```

Install the binary:

```bash
sudo cp .build/release/TypeShield /usr/local/bin/typeshield
sudo chmod +x /usr/local/bin/typeshield
```

Verify installation:

```bash
typeshield --version
```

## Quick Start

Run TypeShield manually:

```bash
typeshield --block-ms 300 --grace-ms 45 --lock-cursor
```

### Recommended Settings

The current recommended configuration is:

```bash
typeshield --block-ms 300 --grace-ms 45 --lock-cursor
```

This provides strong protection against palm drags while remaining responsive during normal trackpad use.

### Verbose Mode

For debugging:

```bash
typeshield --block-ms 300 --grace-ms 45 --lock-cursor --verbose
```

## Command Line Options

| Option            | Description                                                      |
| ----------------- | ---------------------------------------------------------------- |
| `--block-ms N`    | Duration to suppress pointer input after a keypress              |
| `--grace-ms N`    | Immediate protection window after a keypress                     |
| `--lock-cursor`   | Actively pins the cursor to its position during suppression      |
| `--freeze-cursor` | Temporarily disassociates cursor movement from trackpad movement |
| `--allow-scroll`  | Allows scrolling during suppression                              |
| `--verbose`       | Enables debug logging                                            |
| `--version`       | Displays version information                                     |
| `--help`          | Displays help                                                    |

## Cursor Lock Mode

Cursor lock mode is the most effective protection against palm drags.

When enabled:

1. TypeShield records the cursor position at the start of a typing burst.
2. Pointer events are suppressed.
3. The cursor is repeatedly returned to its original position until the suppression window expires.

Enable it with:

```bash
typeshield --lock-cursor
```

## Automatic Startup

Install the LaunchAgent:

```bash
scripts/install-launchagent
```

Verify:

```bash
launchctl print gui/$(id -u)/com.typeshield.agent | head -n 40
```

Remove:

```bash
scripts/uninstall-launchagent
```

### Important Note

macOS `launchd` does not expand:

```text
$HOME
~
```

inside `StandardOutPath` or `StandardErrorPath`.

The included LaunchAgent template uses a placeholder (`__HOME__`) and the installation script automatically replaces it with the correct path.

## Sleep/Wake Recovery

Optional helper agents are available for systems that occasionally lose event taps after sleep:

```bash
extras/install.sh
```

These helpers can:

* Restart TypeShield periodically if it stops running
* Restart TypeShield after wake from sleep

These helpers are optional and are not required for normal operation.

## Permissions

TypeShield requires Input Monitoring permission.

Grant access in:

```text
System Settings
→ Privacy & Security
→ Input Monitoring
```

If TypeShield is updated or rebuilt, macOS may require permissions to be granted again.

## Troubleshooting

### TypeShield Works in Terminal but Not as a LaunchAgent

Verify the agent is running:

```bash
launchctl print gui/$(id -u)/com.typeshield.agent
```

Check for a running process:

```bash
pgrep -af "/usr/local/bin/typeshield"
```

Review logs:

```bash
tail -f ~/Library/Logs/typeshield.err.log
```

### Cursor Still Moves While Typing

Use cursor lock mode:

```bash
typeshield --block-ms 300 --grace-ms 45 --lock-cursor
```

### TypeShield Stops Working After Sleep

Install the optional wake recovery helper:

```bash
extras/install.sh
```

### Rebuild After Updating Source

```bash
swift build -c release
sudo cp .build/release/TypeShield /usr/local/bin/typeshield
typeshieldctl restart
```

## Project Structure

```text
Sources/
Resources/
scripts/
extras/
README.md
CHANGELOG.md
```

## Changelog

Version history is maintained in:

```text
CHANGELOG.md
```

## AI Disclaimer
> All versions up through 1.0.3 were crated using using ChatGPT almost fully, as a way to help me learn Swift, git, and to get back into coding after decades of not writing anything at all. While I did have a specific use for this applicaiton, I mostly started this project with a goal of self-learning. ChatGPT was able to get me started quickly, but ChatGPT did not create code that actually worked as intended. By v1.0.3 I was able to reach a point where I could do manual debugging and write actual modifications that resulted in versions 1.0.4 and 1.0.5 that actually worked. This is, at best, AI written with human verification. But it works.

## License

TypeShield is licensed under the GNU Affero General Public License v3.0 (AGPL-3.0).

You are free to use, modify, and redistribute this software under the terms of the AGPL-3.0 license.

If you modify TypeShield and make it available to users over a network, the AGPL requires that you also make the corresponding source code available under the same license.

See the included `LICENSE` file for the full license text.

