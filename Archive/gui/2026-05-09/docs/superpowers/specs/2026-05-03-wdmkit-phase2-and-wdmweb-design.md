# WDMKit Phase 2 + WDMWeb — design

**Date:** 2026-05-03
**Status:** in progress
**Predecessor:** `2026-05-03-wdmkit-extraction-design.md` (Phase 1 — done)

## Goal

1. **Phase 2.** Drive every drop of frontend-agnostic logic into `WDMKit` so a
   GUI or web app can drive the entire feature set of `wdm` *without ever
   importing `WDMCLI`* and without reimplementing a single line.
2. **Phase 3 (golden goal).** Stand up a second frontend `WDMWeb` — a tiny
   library + executable that imports **only** `WDMKit` and exposes a JSON HTTP
   API with one endpoint per CLI verb, against the same providers/fixture.

## Non-negotiables (from CLAUDE.md)

- Iron law: failing test first, every step, every new lib symbol.
- No fakes, no fallbacks, no silent degradation.
- Super-modular: one public type per file, files ≤ 150 LOC, functions ≤ 30 LOC.
- No new runtime deps. WDMWeb uses Foundation `Network.framework` (Apple, no
  package add).
- Build clean: `swift build -c release -Xswiftc -warnings-as-errors`.
- Full suite green: `swift test` 392+ existing + new Kit/Web tests.

## Layering after this work

```
WDMCore      pure
WDMSystem    effects (CG/IOKit/DisplayServices)
WDMKit       orchestration + typed façade (WDMController + Operation files)
WDMCLI       thin: argv → Kit → exit code + format    (no `import WDMSystem` in Commands/)
WDMWeb       thin: HTTP route → Kit → JSON + status   (no `import WDMSystem`, no `import WDMCLI`)
```

## Phase 2 — operations to extract

Audit shows **24 `Commands/*.swift` files still `import WDMSystem`**. They split
into three groups:

### Group A — leftover imports only (no logic in CLI)

These commands already route through `WDMController` after Phase 1; the
`import WDMSystem` is dead weight. Cleanup: drop the import (WDMKit re-exports
the types via `@_exported import WDMSystem`). Verify with build.

- `ListCommand`, `GetCommand`, `ModeCommand`, `MoveCommand`,
  `FlipCommand`, `FlipOverlayCommand`, `ScaleCommand`, `MutationDispatch`.

### Group B — extract direct provider/effect calls into typed Kit ops

Each gets a new method on `WDMController` (or a new domain-grouped controller
file ≤ 150 LOC, ≤ 30-LOC methods). The CLI command becomes argv → Kit → format.

| Command          | New Kit operation                                                        |
|------------------|--------------------------------------------------------------------------|
| `bind`           | `WDMController.keybindings.list/upsert/remove/reset`                     |
| `rename`         | `WDMController.rename(alias:to:)` writing the alias overlay              |
| `edid`           | `WDMController.edid(_:)` → typed `EDIDInfo`                              |
| `panorama`       | `WDMController.panorama(to:)` (uses screenshotter + CG composition)      |
| `shot-all`       | `WDMController.shotAll(to:)`                                             |
| `pip`            | `WDMController.pip(plan:)` taking `PipPlan` value                        |
| `pip-grid`       | `WDMController.pipGrid(plan:)`                                           |
| `follow`         | `WDMController.follow(plan:)`                                            |
| `watch`          | `WDMController.watch(handler:)` (event stream wrapper)                   |
| `workshop`       | `WDMController.workshop(plan:)` thin preset over `pip-grid`              |
| `cursor-wrap`    | `WDMController.cursorWrap(plan:)` running a `CursorWarpRunner` injected  |
| `daemon`         | `WDMController.daemon.install/uninstall/status/runWatcher`               |
| `hotkeys`        | `WDMController.hotkeys.list/upsert/remove/reset/install/uninstall/run`   |
| `doctor probe`   | `WDMController.doctorProbe(alias:)` returns typed `DoctorReport`         |
| `doctor disconnect` | `WDMController.doctorDisconnect(plan:)` runs capture+wait              |
| `scene`          | `WDMController.scene.applyScene(name:dryRun:)` returns `[SceneEntry]` + spawn |
| `virtual presets`| `WDMController.virtual.presets()` returning `[MobilePreset]`             |
| `virtual create` | `WDMController.virtual.create(spec:durationMs:mirrorOn:)`                |
| `virtual list`   | `WDMController.virtual.list()`                                           |
| `virtual remove` | `WDMController.virtual.remove(target:)`                                  |
| `virtual save`   | `WDMController.virtual.save(name:installAtLogin:)`                       |
| `virtual restore`| `WDMController.virtual.restore(name:dryRun:)`                            |

### Group C — typed errors

`WDMError` gains the cases the new ops can throw (no String-only errors leak):

- `.displayCaptureFailed(UInt32)` — soft-disconnect failure.
- `.hotkeyChordTaken(String)` — registrar refused.
- `.hotkeyChordMalformed(String)` — bad chord token.
- `.virtualSpawnFailed(String)` — child `wdm virtual create` could not be spawned.
- `.virtualNotFound(String)` — `virtual remove` matched nothing.
- `.edidUnavailable(UInt32)` — passed through from provider.
- `.sceneNotFound(String)` — promoted from `profileNotFound`.

CLI keeps current exit-code mapping; WDMWeb maps each to an HTTP status:
4xx for `usage`/`displayNotFound`/`virtualNotFound`/`hotkey…`/`sceneNotFound`,
5xx for `coreGraphicsError`/`ioError`/`displayCaptureFailed`/`virtualSpawnFailed`.

## TDD rhythm per extraction

Every Kit method:

1. **Red.** New test in `Tests/WDMKitTests/<Topic>Tests.swift` constructing a
   `FixtureDisplayProvider` (or recording effect stub) and asserting the typed
   result of the new Kit method. Build fails (symbol missing).
2. **Green.** Add the method on `WDMController` (or topic controller file).
   Move logic from `Commands/<X>Command.swift` into it. Test passes.
3. **Refactor.** CLI command shrinks to argv parsing + Kit call + output
   formatting. `import WDMSystem` removed. Run full `swift test`.

No move that isn't covered by both a fresh Kit-level test and the existing CLI
e2e tests.

## Phase 3 — WDMWeb

### Targets

```swift
.library(name: "WDMWeb", targets: ["WDMWeb"]),
.executable(name: "wdm-web", targets: ["wdm-web"]),
```

`WDMWeb` depends only on `WDMKit`. No `WDMSystem`, no `WDMCLI`. The
executable parses listen address + env, builds a `WDMController`, and runs the
server.

### Transport

- Foundation `Network.framework` (`NWListener` / `NWConnection`) over TCP.
- Hand-rolled minimal HTTP/1.1: request line + headers + optional body. Keep
  the parser ≤ 80 LOC, single file.
- `Content-Type: application/json` for both directions.
- One file per route. Routes are values registered into a `Router` table; the
  request handler dispatches by path + method.

### Routes (one per CLI verb)

```
GET    /version
GET    /displays                       → list
GET    /displays/{alias}               → get
GET    /displays/{alias}/modes         → modes
POST   /displays/{alias}/mode          {"mode":"WxH@Hz"}
POST   /displays/{alias}/main
POST   /displays/{alias}/move          {"x":Int,"y":Int}
POST   /displays/{alias}/rotate        {"degrees":Int}
POST   /displays/{alias}/flip          {"flip":"none|h|v|hv"}
POST   /displays/{alias}/scale         {"WxH":"...", or "factor":F}
POST   /displays/{alias}/brightness    {"value":F}
POST   /displays/{alias}/hdr           {"on":Bool}
POST   /displays/{alias}/ddc           {"control":"...","value":...}
POST   /displays/{alias}/rename        {"name":"..."}
GET    /displays/{alias}/edid
POST   /switch
POST   /cycle
POST   /mirror                         {"source":"...","targets":[...]}
POST   /unmirror                       {"alias":"..."}
GET    /profiles
POST   /profiles                       {"name":"..."}     (save)
POST   /profiles/{name}/restore
DELETE /profiles/{name}
POST   /sleep
POST   /screenshot                     {"alias":"...","path":"..."}
POST   /panorama                       {"path":"..."}
POST   /shot-all                       {"prefix":"..."}
POST   /record                         {"alias":"...","path":"...","durationSec":N}
POST   /pip                            (PipPlan as JSON)
POST   /pip-grid                       (PipGridPlan)
POST   /follow                         (FollowPlan)
POST   /workshop                       (WorkshopPlan)
GET    /events                         (server-sent: chunked text/event-stream)
GET    /hotkeys                        (list)
POST   /hotkeys                        {"chord":"...","command":"..."}    (set)
DELETE /hotkeys/{chord}
POST   /hotkeys/reset
POST   /hotkeys/daemon                 (start in-process listener)
GET    /virtual/presets
POST   /virtual                        (VirtualSpec, runs detached)
GET    /virtual                        (list)
DELETE /virtual/{name|id|all}
POST   /virtual/{name}/save
POST   /virtual/{name}/restore
GET    /doctor/probe[/{alias}]
POST   /doctor/disconnect              {"alias":"...","durationMs":N}
POST   /scene/{name}                   {"dryRun":Bool}
POST   /cursor-wrap                    {"durationMs":N}
```

For long-running operations (`virtual` create, `cursor-wrap`, `doctor disconnect`,
`scene apply`, `pip`), the route returns immediately with a job id and the
operation runs on a detached `Task`. `DELETE /jobs/{id}` cancels.

### Tests

`Tests/WDMWebTests/`:

- `WDMWebRouterTests.swift` — pure parsing of the request line + path matcher.
- `WDMWebHandlerTests.swift` — for each route, instantiate the handler with a
  fixture-backed controller, assert JSON payload + status. No socket required.
- `WDMWebServerSmokeTests.swift` — end-to-end: bind to ephemeral port, drive a
  small set of routes via real HTTP, assert response.

### Build/exit gate

The work is done when:

1. `swift test` is fully green (existing 392 + new Kit + new Web tests).
2. `swift build -c release -Xswiftc -warnings-as-errors` is clean.
3. `grep "import WDMSystem" Sources/WDMCLI/Commands/*.swift` returns empty.
4. `grep "import WDMCLI" Sources/WDMWeb/*.swift Sources/wdm-web/*.swift` returns empty.
5. `swift run wdm-web --port 0 --listen 127.0.0.1 -- WDM_TEST_FIXTURE=Tests/.../two-displays.json &` followed by `curl http://127.0.0.1:<port>/displays` returns the same JSON as `wdm list --json` against the same fixture.

## Out of scope

- GUI app target (WDMMac). Library is shaped to support it but the GUI is a
  separate project.
- Authentication / TLS for WDMWeb. Local-only; bind to `127.0.0.1`. Document
  the threat model in the README; do not invent half-measures.
- Streaming HTTP/2 push. SSE for `/events` is good enough for v1.
