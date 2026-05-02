# Troubleshooting

Known limitations and workarounds.

| Issue | Cause | Workaround |
|---|---|---|
| `wdm rotate` throws "Apple Silicon limitation; use System Settings" | Apple removed `IODisplayConnect` framebuffer services on most Apple Silicon configs (M1/M2/M3 MacBook built-ins, DisplayPort-attached externals). The traditional `IOServiceRequestProbe + kIOFBSetTransform` path has nothing to attach to. | Use System Settings → Displays → Rotation. v0.8.0 will land an experimental `IOMobileFramebuffer` path behind `WDM_EXPERIMENTAL_ROTATE=1`. |
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
