# Troubleshooting

Known limitations and workarounds.

| Issue | Cause | Workaround |
|---|---|---|
| `wdm rotate` or `wdm flip` throws "Apple Silicon limitation; use System Settings" | Apple removed `IODisplayConnect` framebuffer services on most Apple Silicon configs (M1/M2/M3 MacBook built-ins, DisplayPort-attached externals). The traditional `IOServiceRequestProbe + kIOFBSetTransform` path has nothing to attach to. | For rotation: use System Settings → Displays → Rotation. For flip: use **`wdm flip-overlay <id> <axis>`** instead — it works on every Mac including AirPlay, by capturing via ScreenCaptureKit and rendering through a flipping `CALayer`. |
| `wdm flip-overlay` opens a black overlay forever | Screen Recording permission was not granted. | wdm preflights with `CGPreflightScreenCaptureAccess()` and refuses with exit 8 + a clear message that points at System Settings → Privacy & Security → Screen Recording. Approve `wdm` once, then re-run. |
| `wdm flip-overlay` shows two cursors | Default behaviour: `cfg.showsCursor = true` includes the cursor in the captured frame (flipped), and macOS WindowServer additionally draws the real cursor on top. | Intentional — the flipped cursor is what the audience sees. The real cursor on display X is hidden by `CGDisplayHideCursor` when the overlay is on display X (see `AppKitOverlayFlipper`), so on the target display only the flipped cursor remains. SIGTERM/SIGINT/SIGHUP teardown re-shows it. |
| `kill -9 wdm` left the cursor hidden | `CGDisplayHideCursor` is reference-counted; `kill -9` skips teardown. | Matched `CGDisplayShowCursor` runs on SIGINT / SIGTERM / SIGHUP via `DispatchSourceSignal`, so prefer `pkill -TERM` (default `pkill`) over `kill -9`. To restore manually: launch any app that calls `CGDisplayShowCursor`, or reboot. |
| Mac kernel-panics in `AppleHPM` when unplugging projector | macOS kernel bug filed in [issue #1](known-issue-applehpm-panic.md). Not a wdm bug — wdm is pure user-space. | Run **`wdm sleep`** before unplugging — it drains the AppleHPM PD/DP-AltMode handshake queue via `IOPMSleepSystem`. After reboot, `wdm restore last` brings the pre-panic arrangement back. |
| `wdm doctor probe` shows what `wdm list` already shows | They overlap on purpose. `doctor probe` is the diagnostic-first form (one section per display, friendly labels) and is the entry point we'll grow with sub-checks (`probe`, future `rediscover`, future `disconnect`). | Use `doctor probe --json` to feed downstream tooling; use `list --json` for the existing structured shape. |
| `wdm brightness 2` (external monitor) returns empty | `DisplayServices` only supports built-in displays. External monitors need DDC/CI over I²C. | Coming in v0.4.0 via `IOAVServiceCreateWithService`. For now, use the monitor's OSD or `BetterDisplay` for DDC. |
| `wdm` shows "display name: -" | `NSScreen.localizedName` returned empty. Some virtual or third-party DDM displays don't populate it. | Use `wdm get <id> id` and identify by the CGDirectDisplayID. We will add an EDID-based fallback in a future patch. |
| `wdm switch --confirm` HUD steals keys from other apps | CGEvent tap is `listenOnly` — it observes system-wide keypresses without consuming them. Other apps still receive the same key. | This is intentional: the HUD does not block; you can keep typing while it counts down. Press SPACE on top of whatever you're typing to keep the change. |
| Tests fail with "Window not found: App 'wdm' is running but has no windows or dialogs" via `peekaboo` | The HUD lives at `level: .statusBar` which is above the layer Accessibility APIs enumerate. | Not a bug. The HUD is visible and accepts keys — peekaboo just can't introspect it. Use `osascript -e 'tell application "System Events" to keystroke " "'` for scripted SPACE. |
| Code-sign verification fails on first install | The downloaded binary's signing identity isn't trusted yet by macOS Gatekeeper. | Right-click → Open the binary once, or run `xattr -dr com.apple.quarantine /usr/local/bin/wdm`. The official installer (`install.sh`) verifies notarization, which avoids the quarantine. |
| `make smoke` reports "0 tests in 0 suites" | The hardware-gated tests use `@Suite(.enabled(if:))` — when the env var isn't set, the suite is skipped, not failed. | Run with `WDM_REAL_HARDWARE=1 make test` to actually run the smoke tests. |
| The `--confirm` HUD doesn't appear | The wdm process needs Accessibility permission for the global `CGEvent.tapCreate`. | Grant in System Settings → Privacy & Security → Accessibility → wdm. The first run prompts. The HUD's window itself shows regardless; only the global keypress catcher needs the grant. |

## Diagnostic commands

```sh
wdm version                       # what's installed
wdm doctor probe                  # human-readable per-display diagnostic (mode/origin/main/rotation/mirror)
wdm doctor probe --json           # same, machine-parseable
wdm list --json | jq .            # full structured state
wdm modes main                    # is the mode you want even available?
ls ~/.config/wdm/profiles/        # what profiles do I have
cat ~/.config/wdm/profiles/last.json  # the most recent pre-mutation state
```

## Filing a bug

Open an issue at https://github.com/Arthur-Ficial/workshop-display-manager/issues with:

1. `wdm version`
2. `sw_vers`
3. `wdm list --json` (redact serial numbers if sensitive)
4. The exact command you ran
5. The full stderr output

The issue template at `.github/ISSUE_TEMPLATE/bug.md` walks through these.
