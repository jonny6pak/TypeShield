# Changelog

## 1.0.5

- Fix LaunchAgent packaging/docs to avoid `$HOME` in `StandardOutPath` / `StandardErrorPath`.
- Add `scripts/install-launchagent` and `scripts/uninstall-launchagent`.
- Keep recommended defaults at `--block-ms 300 --grace-ms 45 --lock-cursor`.
- Clarify that optional resilience helpers are separate from the core TypeShield agent.

## 1.0.4

- Add optional `--lock-cursor` mode.
- Saves cursor position at the beginning of suppression and repeatedly warps the cursor back until the block window expires.
- Intended for systems where the visible cursor still moves even while pointer events are blocked.
- Can be used alone or with `--freeze-cursor`.

## 1.0.3

- Add optional `--freeze-cursor` mode.
- During suppression, cursor association is disabled with `CGAssociateMouseAndMouseCursorPosition(false)`.
- Cursor association is restored automatically after the block window expires and during shutdown.
- Intended for systems where `CGEventTap` returns `nil` for movement events but the visible cursor still moves.

## 1.0.2

Reliability/correctness fixes:

- Use `.cghidEventTap` for both keyboard and pointer taps.
- Capture keypress timestamps immediately and write synchronously.
- Use only `keyDown` for typing suppression timing.
- Replace `passRetained` with `passUnretained` in event tap callbacks.
- Update watchdog so it only re-enables taps when they are disabled.

## 1.0.1

- Added tap re-enable handling and a watchdog for disabled event taps.
- Added optional resilience helpers for auto-restart and wake recovery.
