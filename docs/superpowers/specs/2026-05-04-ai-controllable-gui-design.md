# AI-Controllable WDMMac GUI — design

**Date:** 2026-05-04
**Status:** in progress
**Predecessor:** `2026-05-03-wdmkit-phase2-and-wdmweb-design.md`

## Goal

Every visual frontend of `wdm` — starting with WDMMac, applying to every
future GUI / web / MCP frontend — exposes every single user interaction over
a local remote-control API. An AI agent (or a shell pipeline) can drive
every click, scroll, drag, sheet, and countdown the same way a human would,
while the local human watches it happen with a halo overlay.

The reference shape is Vercel's `agent-browser`: an accessibility-style
scene **snapshot** with stable `@e1`-style refs is the **primary** state
surface; PNG **screenshots** are optional; **events** stream live over SSE.
Headed by default, headless for tests.

## Non-negotiables (inherited from `CLAUDE.md`)

- Iron law: failing test first, every step. The tests for this work drive
  the UI through the remote API itself — no in-process shortcuts.
- No fakes / fallbacks: if a SwiftUI control isn't yet wired to a remote
  ID, the snapshot must omit it (and the e2e test must fail) rather than
  invent a fake ref.
- Super-modular: one public type per file, ≤ 150 LOC per file, ≤ 30 LOC
  per function. `WDMRemoteControl` is its own target, separate from
  `WDMKit`, separate from `WDMMacRemote`.
- No new runtime deps. HTTP server uses Foundation `Network.framework`
  exactly like `WDMWeb` already does.
- Build clean with `-warnings-as-errors`.

## Layering

```
WDMCore
WDMSystem
WDMKit                  (existing: typed façade)
WDMRemoteControl        NEW: RemoteControllable protocol + transport server
                              + SceneTree / RemoteAction / UIEvent value types
WDMCLI    WDMWeb        (existing siblings)
WDMMac                  (in-progress)
  └── WDMMacRemote      NEW: SwiftUI ↔ RemoteControllable adapter
wdm-mac-control         NEW: unix-pipe companion CLI (sibling of wdm-mac)
```

`WDMRemoteControl` knows nothing about SwiftUI. `WDMMacRemote` is the only
place SwiftUI meets the remote protocol. Future `WDMWebRemote`,
`WDMMCPServer`, `WDMShortcutsAdapter` plug in the same way.

## API surface (mirrors `agent-browser`)

All routes are `127.0.0.1:<port>` only, no TLS, per-launch bearer token in
`~/.config/wdm/remote.json` written 0600.

### State (read)

- `GET /ui/snapshot?interactive=1&compact=1&depth=N&scope=<ref>` — JSON
  scene tree, every node has
  `{ref, role, label, value, bounds, state, children}`. Refs are stable per
  launch (`@e1, @e2, ...`). The default response is the **primary** state
  surface — same role as `agent-browser snapshot -i`.
- `GET /ui/state` — typed app-level state:
  `{selectedDisplayId, openSheets, toasts, safeTx, recordings, watchEvents}`.
  Cheaper than a full snapshot for polling.
- `GET /ui/screenshot[?ref=@e2]` — PNG of the live window (or one element).
  Optional convenience for AI agents that want to see, not just read.
- `GET /ui/diff/snapshot` — JSON diff vs the previous snapshot the same
  client requested. Lets the AI react only to actual changes.
- `GET /ui/events` — SSE stream of `UIEvent` records: selection, sheet,
  toast, safe-tx tick, watch-event passthrough, snapshot-changed marker.
  This is mandatory; the AI must not need to poll.

### Actions (write)

Every body is `{"ref":"@e2", ...}` (or `{"selector":{...}, ...}`). Every
action returns `{"ok":bool, "snapshotVersion":N, "eventIds":[...]}` so the
caller can correlate the resulting `UIEvent`s.

- `POST /ui/click {ref}`
- `POST /ui/dblclick {ref}`
- `POST /ui/hover {ref}`
- `POST /ui/focus {ref}`
- `POST /ui/scroll {dir, px, ref?}`
- `POST /ui/scrollintoview {ref}`
- `POST /ui/drag {fromRef, toRef? | toPoint?}`
- `POST /ui/fill {ref, text}`
- `POST /ui/type {ref, text}` (no clear)
- `POST /ui/press {key}` (window-level)
- `POST /ui/select {ref, value | values}`
- `POST /ui/check {ref}` / `/ui/uncheck {ref}`

### Sessions / lifecycle

- `GET /ui/version` — `{server, kit, ui}` build versions.
- `POST /ui/wait {ref?, ms?, eventType?}` — block until condition.
- `POST /ui/highlight {ref, ms}` — manual halo (debugging aid; the
  automatic halo always fires on real actions).

## Visual feedback — halo overlay (mandatory)

Every action that mutates UI MUST trigger a brief glass-effect halo around
the target element with the action's verb label ("click", "fill", "drag")
fading out over ~600 ms. This runs on the WDMMac main actor regardless of
whether the trigger came from the local human, the remote API, or a unit
test. The local user can always tell what the AI just did. Disabled only
when `--no-halo` is passed at launch (intended for video recording).

## Defaults & flags

- `wdm-mac` (no flag) — no listener bound, no token written.
- `wdm-mac --remote` — bind `127.0.0.1:<random free port>`, write
  `~/.config/wdm/remote.json` (0600) with `{port, token, pid, startedAt}`.
- `wdm-mac --remote --port N` — fixed port; refuses to start if taken.
- `wdm-mac --remote --token-file <path>` — token at custom path.
- `wdm-mac --remote --no-token` — explicit opt-out for local hacking; the
  server logs a warning to stderr on every request.
- `wdm-mac --remote --headless` — render the SwiftUI scene offscreen via
  an `NSHostingView` of fixed size. No window, no Dock entry; full
  remote-control surface still works. Powers hermetic e2e tests and a
  future headless MCP frontend.
- `wdm-mac --remote --no-halo` — disable halo overlay for video capture.

## `wdm-mac-control` — companion CLI

A second tiny executable beside `wdm-mac`. Imports only `WDMRemoteControl`.
Reads `~/.config/wdm/remote.json` to discover port + token. Surface mirrors
`agent-browser` 1:1:

```
wdm-mac-control open                      # start wdm-mac --remote if not running
wdm-mac-control snapshot -i --json
wdm-mac-control click @e2
wdm-mac-control fill @e3 "Workshop A"
wdm-mac-control scroll down 200
wdm-mac-control drag @e5 @e9
wdm-mac-control screenshot out.png
wdm-mac-control wait --ref @e2 --visible --timeout 5000
wdm-mac-control events                    # tail SSE
wdm-mac-control diff snapshot
wdm-mac-control eval '<json action>'      # raw POST escape hatch
```

Pure unix-pipe demo (proves every UI verb is reachable):

```
wdm-mac --remote --headless &
wdm-mac-control snapshot -i --json \
  | jq '.tree[] | select(.role=="button" and .label=="Cycle main") | .ref' \
  | xargs -I{} wdm-mac-control click {}
```

If a UI element can't be expressed this way, it has no `.remoteID(…)` —
the implementation is incomplete.

## Element identity

Every interactive view declares a stable `.remoteID("…")` (a `WDMMac`-side
`ViewModifier` aliased to `.accessibilityIdentifier("…")`) at view-
declaration time, e.g.:

```
Button("Cycle main") { vm.cycleMain() }
  .remoteID("titlebar.cycleMain")

Picker("Mode", selection: $vm.mode) { ... }
  .remoteID("inspector.mode.dropdown")
```

`@e1`-style refs are assigned by `WDMMacRemoteAdapter` at snapshot time and
remain stable across snapshots while the underlying `remoteID` is alive.
Refs are NOT stable across launches — clients should look up by `remoteID`
or by role+label, not by `@e2` literal between sessions.

Auto-generated IDs are forbidden. They re-shuffle on re-render and break
the contract.

## Test strategy

Three layers, all gated by `make test` with no env vars:

1. **`WDMRemoteControlTests` — unit.** `RemoteControllable` round-trip
   against a `FixtureRemoteControllable` (a tiny in-memory tree). Asserts
   snapshot serialisation, action dispatch, event ordering.
2. **`WDMMacRemoteTests` — adapter.** Hosted `NSHostingView` + the real
   `WDMMacRemoteAdapter`. Asserts every `.remoteID("…")` declared in the
   tree shows up in `snapshot()`, every action resolves to the right
   callback.
3. **`WDMMacE2ETests` — full e2e via the API.** Spawns
   `wdm-mac --remote --headless` against `WDM_TEST_FIXTURE`, drives it via
   `URLSession`, asserts the post-state through `wdm` CLI verbs (cross-
   checks two frontends agree on world state). One e2e per existing UI
   ticket.

Real-hardware smoke (`make smoke-mac-remote`, env-gated) does the same
against a real window.

## Honest unsupported paths

- `--remote --headless` on a Mac without offscreen `NSHostingView`
  support → throw at startup.
- `POST /ui/drag` to a target that doesn't accept drops → typed
  `{"ok":false, "error":"unsupported", "reason":"target rejects drag"}`.
  No silent success.
- Action on a stale ref (element removed since last snapshot) → typed
  `{"ok":false, "error":"stale-ref"}`. The AI can re-snapshot and retry.

## Out of scope (this spec)

- WDMWeb's `--remote` — same protocol but later. Adding it to `WDMWeb` is
  a small adapter once `WDMRemoteControl` ships.
- A live screencast endpoint (vs on-demand screenshots) — defer.
- Network-exposed remote control — local-only forever; cross-machine
  control is a Tailscale problem, not an HTTP-server problem.
- An MCP server frontend — natural follow-up, but its own meta ticket.
