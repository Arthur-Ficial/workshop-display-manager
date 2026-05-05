# Spec: WDMMac Inspector — Brightness slider

> Feature-level spec under the parent `SPEC.md`. Closes one item from
> `tasks/todo.md`. Reads/writes the same Kit op the CLI's `wdm
> brightness <id> [0..1]` exposes — SSOT preserved.

## Assumptions surfaced

1. Brightness is read-only on most external monitors; the CLAUDE.md "honest unsupported-path policy" applies — the slider must visibly refuse rather than silently set 0 or hide.
2. The fixture provider already supports brightness via `state.brightness` table; tests can pre-seed `state.brightness["1"] = 0.5` and assert reads/writes round-trip.
3. The slider lives in the existing Inspector (right column), under a new `BRIGHTNESS` section beneath `GEOMETRY`.
4. **Slider is reactive — every tick is a write.** The user expects the screen brightness to change as they drag, exactly like macOS System Settings. The CLI's transactional semantics don't apply here: `controller.brightness(_:value:confirmer:)` is a one-call DisplayServices write with `AutoYesConfirmer` (no actual safe-tx round-trip), and 60 Hz drag updates cost ≪ 1% CPU. Spec amended after live user feedback 2026-05-05 — the original "drag-end commit" was wrong.
5. No global keyboard shortcut for now — slider is mouse/AX-only. AI agents drive it via `/ui/click` or future `/ui/setValue`.

→ Correct any of these or they govern the rest.

## Objective

Workshop facilitators see and control the built-in display's brightness from the GUI without dropping to the CLI. External monitors that don't support DDC/CI brightness show a single-line "Brightness control unavailable" hint instead of a slider — honest about the hardware limit. The same `controller.brightness(_:value:confirmer:)` Kit op is invoked, so any fix to brightness handling lands in CLI, web, and Mac at once.

## Tech Stack

- Already in this repo: SwiftUI, `WDMController.brightness(_:)` (read), `WDMController.brightness(_:value:confirmer:)` (write), `FixtureDisplayProvider` brightness table.

## Commands

```sh
make build                                   # swift build
make test                                    # swift test
swift test --filter HeadlessBrightness       # the new e2e suite
make lint-remote-coverage                    # remoteIDs covered by tests
```

## Project Structure

```
Sources/WDMMac/
  Views/Inspector/
    InspectorBrightness.swift      ← NEW. ≤80 LOC. SwiftUI Slider + label OR refusal hint.
  Views/InspectorView.swift        ← +1 line: `InspectorBrightness(vm: vm, tile: tile)`
  ViewModels/DisplaysListVM.swift  ← + `brightness(forDisplayID:) -> Float?`
                                    ← + `setBrightness(displayID:, value:)`
                                    ← + reload brightnesses inside reload()
Sources/WDMMacRemote/
  WDMMacRemoteRunner.swift         ← register `inspector.brightness.slider` +
                                    `inspector.brightness.value.<n>` (preset clicks)
                                    in the headless registry — AX walker can't see
                                    SwiftUI without a window.
Tests/WDMMacE2ETests/
  HeadlessBrightnessTests.swift    ← NEW. Three cases: read, write, refusal.
```

## Code Style

```swift
public struct InspectorBrightness: View {
    @ObservedObject var vm: DisplaysListVM
    let tile: DisplaysListVM.Tile

    public var body: some View {
        if let value = vm.brightness(forDisplayID: tile.displayID) {
            HStack {
                Image(systemName: "sun.min")
                Slider(value: Binding(
                    get: { Double(value) },
                    set: { vm.setBrightness(displayID: tile.displayID, value: Float($0)) }
                ), in: 0...1)
                .accessibilityIdentifier("inspector.brightness.slider")
                Image(systemName: "sun.max")
            }
        } else {
            Text("Brightness control unavailable on this display.")
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("inspector.brightness.unavailable")
        }
    }
}
```

## Testing Strategy

- **swift-testing** + Swift Testing's `#expect` macro.
- E2E suite `HeadlessBrightnessTests`:
  - **Read**: pre-seed fixture brightness `state.brightness["1"] = 0.4`, snapshot, assert `inspector.brightness.value` node carries `value: "0.40"` (or similar formatted string).
  - **Write**: post `/ui/click` on a preset (`inspector.brightness.value.075`), wait, read fixture file, assert `state.brightness["1"] == 0.75`.
  - **Refusal**: select a display whose `state.brightness` entry is nil, snapshot, assert `inspector.brightness.unavailable` is present and `inspector.brightness.slider` is absent.
- The write path uses preset click points (`0.25 / 0.50 / 0.75 / 1.00`) registered in the remote registry, not raw slider drag — `/ui/click` is the only verb the headless test rig supports today. Adding `/ui/setValue` is out of scope.

## Boundaries

### Always do
- Probe the displays' brightness support at read-time; refuse explicitly when nil.
- Route every read AND write through `controller.brightness(...)` — never call `provider.*` from the VM.
- Pin a remoteID to every interactive element the test asserts on.

### Ask first
- Adding `/ui/setValue` or any new remote-control verb (out of scope here).
- Probing DDC/CI for external monitors (CLAUDE.md says out of scope).
- Persisting brightness in profiles (outside this feature).

### Never do
- Silently fall back to 0.5 when brightness is unsupported.
- Render a slider for unsupported displays.
- Throttle slider writes pre-emptively without a profile justifying it — reactivity beats hypothetical efficiency.

## Success Criteria

- [ ] `swift test --filter HeadlessBrightness` passes (3 cases: read, write, refusal).
- [ ] `make lint-remote-coverage` passes — every new `inspector.brightness.*` remoteID is covered by a test click or assertion.
- [ ] Full suite green; release build `-warnings-as-errors` clean.
- [ ] The CLAUDE.md "honest refusal" pattern visible: unsupported displays show `inspector.brightness.unavailable`, not a fake slider.

## Open Questions

- None mechanical. Visible-but-out-of-scope: continuous slider drag (would need `/ui/setValue`), DDC/CI for externals.
