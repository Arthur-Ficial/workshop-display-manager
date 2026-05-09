# Implementation Plan: WDMMac Inspector Brightness Slider

> Generated 2026-05-05 by `/plan` against `tasks/brightness-slider-spec.md`.
> Vertical slices: each task is a complete read OR write OR refusal path
> with its own e2e test. Sequential because the VM property is shared.

## Overview

Add brightness control to the WDMMac Inspector. Read shows current value or "unavailable" hint. Write uses preset click points (`0.25 / 0.50 / 0.75 / 1.00`) registered in the headless registry — the e2e harness drives `/ui/click`, not slider drag. The CLAUDE.md "honest unsupported-path policy" governs the unavailable case.

## Architecture Decisions

1. **Preset clicks, not slider drag.** The headless test rig only supports `/ui/click`; adding `/ui/setValue` is its own scope. Four preset click targets (`inspector.brightness.value.025/050/075/100`) cover the practical workshop use case — coarse but real.
2. **VM caches brightness per displayID.** `vm.brightness(forDisplayID:)` returns `Float?` — nil = unsupported, present = current. Avoids re-reading the controller on every render.
3. **Refusal is structural, not graceful.** When `controller.brightness(alias)` returns nil, the InspectorBrightness view renders the `inspector.brightness.unavailable` text — NEVER a slider with `value: 0.5`.

## Dependency Graph

```
DisplaysListVM.brightness(forDisplayID:) -> Float?         (foundation)
    │
    ├── InspectorBrightness view                           (renders read OR refusal)
    │       │
    │       └── InspectorView wires it in                  (one line)
    │
    └── DisplaysListVM.setBrightness(displayID:, value:)   (write)
            │
            └── WDMMacRemoteRunner registers presets       (4 click targets per supported display)
```

Bottom-up build order: foundation → read view → write VM method → registry presets.

## Task List

### Phase 1: Foundation + Read path

- [ ] **Task 1: VM brightness read + InspectorBrightness view + Inspector wiring**
  - Acceptance:
    - `DisplaysListVM.brightness(forDisplayID:) -> Float?` returns the cached brightness; nil if unsupported.
    - `reload()` populates a `brightnesses: [UInt32: Float?]` map by calling `controller.brightness(...)` per display.
    - `Sources/WDMMac/Views/Inspector/InspectorBrightness.swift` exists; renders `Slider` (with `inspector.brightness.slider` remoteID) when value is present, or `Text("Brightness control unavailable")` (with `inspector.brightness.unavailable` remoteID) when nil.
    - `InspectorView` includes the new section under `GEOMETRY`.
  - Verify:
    - New e2e: `HeadlessBrightnessTests.readShowsCurrentValue` — pre-seed fixture `state.brightness["1"] = 0.4`, snapshot, assert `inspector.brightness.value` carries label/value indicating 0.40.
    - New e2e: `HeadlessBrightnessTests.unsupportedShowsUnavailableHint` — display whose brightness is nil → `inspector.brightness.unavailable` present, `inspector.brightness.slider` absent.
  - Files: `Sources/WDMMac/ViewModels/DisplaysListVM.swift`, `Sources/WDMMac/Views/Inspector/InspectorBrightness.swift` (new), `Sources/WDMMac/Views/InspectorView.swift`, `Sources/WDMMacRemote/WDMMacRemoteRunner.swift`, `Tests/WDMMacE2ETests/HeadlessBrightnessTests.swift` (new)
  - Scope: M (5 files)
  - Depends on: nothing

### Phase 2: Write path

- [ ] **Task 2: Preset click points → setBrightness → fixture mutation**
  - Acceptance:
    - `DisplaysListVM.setBrightness(displayID:, value:)` calls `controller.brightness(alias, value:, confirmer: AutoYesConfirmer())`, then refreshes the brightness cache.
    - `WDMMacRemoteRunner` registers 4 entries per supported display: `inspector.brightness.value.025/050/075/100` (each clickable).
    - Click on any preset writes that value through to the fixture.
  - Verify:
    - New e2e: `HeadlessBrightnessTests.clickingPresetWritesBrightness` — pre-seed fixture brightness=0.4, click `inspector.brightness.value.075`, wait, read fixture file, assert `state.brightness["1"] == 0.75`.
  - Files: `Sources/WDMMac/ViewModels/DisplaysListVM.swift`, `Sources/WDMMacRemote/WDMMacRemoteRunner.swift`, `Tests/WDMMacE2ETests/HeadlessBrightnessTests.swift` (extend)
  - Scope: S (3 files)
  - Depends on: Task 1

### Checkpoint
- [ ] `swift test --filter HeadlessBrightness` — all 3 cases pass
- [ ] **Visual headed e2e** — `WDM_HEADED_E2E=1 swift test --filter HeadedBrightness` runs the same flow against a *headed* `wdm-mac` so SwiftUI actually lays out the slider and AppKit's accessibility tree exposes it. **Project-wide rule from SPEC.md "Always do" — every feature needs this. The headless registry path is necessary but not sufficient.** A test asserting the *absence* of `inspector.brightness.slider` from the headless snapshot is vacuous if the registry never publishes that ID — only the headed path can prove the SwiftUI Slider really exists and is reachable.
- [ ] `swift test` — full suite green
- [ ] `swift build -c release -Xswiftc -warnings-as-errors` — clean
- [ ] `make lint-remote-coverage` — every new remoteID covered by a test click or assertion

### Phase 3: Review + Ship

- [ ] **Task 3: `/review`** (5-axis)
- [ ] **Task 4: `/ship`** (parallel personas + GO/NO-GO)

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| AX walker doesn't see SwiftUI Slider in headless mode | Med | Don't depend on it. Register all assertions through the remote registry (label/value carried explicitly). |
| `controller.brightness` reads on every reload may be expensive on real hardware | Low | This is fixture-only in tests; production path is per-frame brightness which is fast. Re-evaluate if it shows up in profiling. |
| Snapshot label format change breaks the test | Low | Test asserts `value: "0.40"` via `node.value`, not on label text — survives copy-edits. |

## Open Questions

- None mechanical. Slider-drag write is explicitly out of scope.
