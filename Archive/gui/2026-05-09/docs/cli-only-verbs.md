# CLI-only verbs (allowlist)

These CLI verbs intentionally do **not** have a GUI surface. The list is the source of truth for `scripts/lint-gui-parity.sh` — if a verb appears here, the GUI lint won't complain that it's missing from `Sources/WDMMac/**`.

A verb belongs on this list iff:
- It's a low-level utility better suited to a shell pipeline than a button, OR
- It's an experimental / advanced feature not exposed to typical workshop facilitators, OR
- It's a build / installer / shell-completion helper, OR
- It's a sub-verb whose parent already has a GUI surface (e.g. `arrange move` is CLI-only because the parent `arrange` is exposed via Stage drag-rearrange in M5d).

Adding to this list MUST come with a one-line justification. The lint reads only the canonical-form table below.

## Canonical form

| verb | controller-method | justification |
|---|---|---|
| arrange | arrangement/setArrangement | Drag-to-rearrange in Stage covers this; sub-verbs `move`/`set` are CLI-only by design |
| bind | (interactive) | Interactive keybinding wizard — TTY-only by design |
| cycle | cycleMain | Forward-cycle of main display; not a workshop facilitator need |
| doctor | doctorProbe/doctorDisconnect | M5b adds the probe panel; disconnect surfaces as Reset action label only today |
| get | get | Read-only display field accessor; surfaced implicitly via Inspector snapshot |
| hdr | hdr/setHDR | HDR toggle; not in workshop flows yet |
| modes | modes | Read-only mode list; surfaced implicitly via Inspector mode dropdown (driven by snapshot) |
| completions | (none) | Shell completions installer; not a runtime feature |
| cursor-wrap | (interactive) | Long-running mouse-warp daemon; not user-facing |
| daemon | (none) | LaunchAgent installer; system-level setup, not GUI |
| ddc | ddcRead/ddcWrite | External-monitor DDC/CI controls; out of scope per CLAUDE.md hardware caveats |
| doctor disconnect | doctorDisconnect | Sub-verb; reset-action covers the user case in GUI |
| edid | (read-only) | Raw EDID dump; surfaced indirectly in Inspector identity panel |
| flip | flip | IOKit framebuffer flip; GUI uses the software flip-overlay path (works on every Mac) |
| focus | focus | Window-management utility; out of GUI scope |
| follow | follow | Cursor-following window helper; out of GUI scope |
| hotkeys | (M5e adds GUI) | TEMPORARILY here — M5e wires the Settings → Hotkeys pane; remove this row at M5e |
| manpage | (none) | Generates man/wdm.1; not a runtime feature |
| move-window | moveWindow | Window-management utility; out of GUI scope |
| panorama | panorama | Experimental panorama scene; not in workshop flows |
| pip-grid | pipGrid | Batch PiP for multiple displays; single-PiP button is the GUI equivalent |
| rename | rename | Display rename via EDID overlay; CLI utility, not in workshop flows |
| scale | scale | HiDPI scaling; surfaced via Mode dropdown in GUI |
| scene | (experimental) | Experimental scene composer; not user-facing |
| screen-windows | screenWindows | Window inventory utility; out of GUI scope |
| shot-all | shotAll | Batch screenshot; single Record action is the GUI equivalent |
| wallpaper | wallpaper | Read-only wallpaper URL accessor; T-bg-1 (#125) wires the GUI tile-preview render in a follow-up slice |
| sleep | sleep | System sleep; out of GUI scope (issue #1 workaround for AppleHPM unplug) |
| stream | stream | Low-level capture stream; not user-facing |
| switch | switchMain | CLI-only; Make-Main button covers the user case in GUI |
| tile-app | tileApp | Window-tiling utility; out of GUI scope |
| watch | (M5c adds GUI) | TEMPORARILY here — M5c wires the live event-log panel; remove this row at M5c |
| workshop | workshopStart/workshopStop | Workshop start/stop choreography; CLI-only orchestration |

## Rules for the lint

`scripts/lint-gui-parity.sh` parses ONLY the canonical-form table above. Format:

```
| <verb> | <controller-method-or-marker> | <justification> |
```

The first column is the verb (kebab-case). The lint:
- Discovers every `Sources/WDMCLI/Commands/*Command.swift` and derives the verb from the filename (e.g., `FlipOverlayCommand.swift` → `flip-overlay`).
- For each verb NOT in this allowlist, it must find at least one occurrence in `Sources/WDMMac/**` or `Sources/WDMMacRemote/**` of either:
  - the controller method called by the CLI command, OR
  - the verb token used as a remoteID prefix or label.
- Verbs in the allowlist are skipped (assumed intentional).

## Web parity

**Dropped from v1.0.0 scope** (user decision 2026-05-05). The Web frontend (`wdm-web`) remains a proof of concept that the lib is interface-agnostic — it isn't a shipped product, and gating v1.0.0 on Web parity would be a distraction. Track Web gaps post-1.0.0 if/when the Web frontend gets promoted to a shipped product.
