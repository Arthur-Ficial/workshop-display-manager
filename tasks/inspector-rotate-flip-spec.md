# Spec: Inspector rotation + flip segments wire to real Kit ops

> User-reported 2026-05-05: "the GEOMETRY clicks should actually do
> something — make this all work, with remote-control e2e tests."
>
> Current state: clicking 0°/90°/180°/270° is a literal no-op
> (`{ _ in /* M2 placeholder */ }`); flip clicks update VM-only state
> (`vm.setFlip(...)`) and never reach the controller. Both violate
> CLAUDE.md "no fakes / no fallbacks".

## Assumptions

1. The user is running on an Apple Silicon MacBook Air with a Built-in Retina Display, where CLAUDE.md documents that `wdm rotate` and `wdm flip` throw a clear refusal because `IODisplayConnect` isn't exposed for that built-in. The GUI must surface that refusal honestly — not silently catch-and-ignore.
2. `controller.rotate(alias, degrees:, confirmer:)` and `controller.flip(alias, flip:, confirmer:)` are the existing Kit ops the CLI uses (`wdm rotate`, `wdm flip`).
3. The fixture provider supports both real-write paths — the e2e tests verify behaviour by reading the fixture file post-click, the same shape used for the brightness / arrangement tests.
4. `AutoYesConfirmer` for the GUI flow (no terminal prompt is reachable).

→ Correct now or these stand.

## Objective

Click on a rotation segment → display actually rotates (via the same Kit op `wdm rotate <id> <0|90|180|270>` exposes) OR a refusal message surfaces if the hardware doesn't support it. Same for flip. Workshop facilitator gets either a real effect or an honest "this hardware can't" — never silent failure.

## Project Structure

```
Sources/WDMMac/ViewModels/DisplaysListVM.swift          + setRotation(displayID:, degrees:), + apply path for setFlip()
Sources/WDMMac/Views/Inspector/InspectorGeometry.swift  rotation onPick → vm.setRotation; flip onPick → vm.applyFlip
Tests/WDMMacE2ETests/HeadlessGeometryTests.swift        NEW. Real fixture writes for both verbs; refusal path covered too.
Tests/WDMMacE2ETests/HeadedGeometryTests.swift          NEW. Visual headed e2e per SPEC.md "Always do" rule.
```

## Code Style

```swift
// VM — same shape as setBrightness
public func setRotation(displayID: UInt32, degrees: Int) {
    do {
        _ = try controller.rotate(String(displayID), degrees: degrees, confirmer: AutoYesConfirmer())
        lastError = nil
    } catch {
        lastError = "Rotate failed: \(error)"
    }
    reload()
}

public func applyFlip(displayID: UInt32, flip: Flip) {
    do {
        _ = try controller.flip(String(displayID), flip: flip, confirmer: AutoYesConfirmer())
        lastError = nil
    } catch {
        lastError = "Flip failed: \(error)"
    }
    reload()
}
```

## Testing Strategy

- **HeadlessGeometryTests** (default-runs):
  - `clickingRotationSegmentRotatesFixture`: pre-seed display 1 at rotation 0, click `inspector.rotate.180`, read fixture, assert display 1 rotation == 180.
  - `clickingFlipSegmentFlipsFixture`: pre-seed display 1 with flip none, click `inspector.flip.h`, read fixture, assert display 1 flip == .horizontal.
  - `unsupportedRotationSurfacesError`: configure fixture to reject rotation, click, assert lastError surfaces in the registry as `inspector.geometry.lastError`.
- **HeadedGeometryTests** (gated WDM_HEADED_E2E=1):
  - `geometrySegmentsClickableInHeadedAXTree`: spawn fresh wdm-mac, click each rotation + flip remoteID via `/ui/click`, assert all return ok:true.

## Boundaries

### Always do
- Route through `controller.rotate` / `controller.flip` — the Kit op is the SSOT.
- On unsupported hardware, surface the refusal via `lastError` and (registered as) `inspector.geometry.lastError` so AI agents see it the same way humans do.
- Real fixture-mutation assertions, not "click returns 200".

### Ask first
- Adding a confirmation dialog (workshop facilitators want speed; safe-tx is in the Kit op already if it's wired in).
- Wiring rotation that doesn't survive logout (the Kit op uses `.forSession` already; no new decision needed).

### Never do
- Catch-and-ignore the controller's error. CLAUDE.md "no fakes" — silent failure is forbidden.
- Use Kit's `.flip` or `.rotate` types directly in the View — go through the VM.

## Success Criteria

- [ ] HeadlessGeometryTests passes all 3 cases.
- [ ] HeadedGeometryTests runs against a fresh wdm-mac and passes — *real run*, not just gated.
- [ ] Full suite green; release clean.
- [ ] If rotate/flip refuses on the user's MacBook Air, that refusal is visible in the headed snapshot via `inspector.geometry.lastError`.

## Open Questions

- None mechanical. The hardware-specific refusal behaviour is already in CLAUDE.md.
