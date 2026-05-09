# Spec: Inspector HEADER shows "Mirror of 0X" tag

> Tiny S-sized polish per the design briefing's listed status tags
> ("Main, Mirror of 0X, REC 00:14, Headless, HDR"). Today the
> Inspector HEADER shows `Main` but never `Mirror of …`.

## Assumptions

1. `DisplayInfo.mirrorSource: UInt32?` is the source. Already populated by `controller.list()`. Just needs to flow through `DisplaysListVM.Tile`.
2. Format: "Mirror of 0X" where X is the 1-based index of the source display in the visible tile list (matches the badge convention `01`, `02`, … used on Stage tiles).
3. Headless registry: a passive text node `inspector.title.mirror` carrying the mirror-of label when set. Same pattern as `inspector.geometry.lastError`.
4. Badge appears IN ADDITION to (not instead of) the Main badge — a mirroring main display would show both.

→ Correct now or these stand.

## Objective

When a display is mirroring another, the Inspector HEADER shows a "Mirror of 0X" badge under the title. Users see at a glance "this display isn't unique — it's a mirror." Closes one design-briefing status-tag item.

## Project Structure

```
Sources/WDMMac/ViewModels/DisplaysListVM.swift          + Tile.mirrorSource: UInt32?
Sources/WDMMac/Views/Inspector/InspectorHeader.swift    if tile.mirrorSource: Badge("Mirror of 0X")
Sources/WDMMacRemote/WDMMacRemoteRunner.swift           register `inspector.title.mirror` for the selected tile
Tests/WDMMacE2ETests/HeadlessMirrorTagTests.swift       NEW. Pre-seeds fixture with a mirror, asserts badge surfaces.
```

## Testing Strategy

- **Headless e2e** (default-runs):
  - `mirrorTagAppearsForMirroredDisplay`: pre-seed fixture with display 2 mirroring display 1, click `displays.tile.2`, snapshot, assert `inspector.title.mirror` carries `Mirror of 01` (display 1 is index 0 → `01`).
  - `noMirrorTagWhenIndependent`: default fixture has no mirrors, snapshot, assert `inspector.title.mirror` is absent.

## Boundaries

### Always do
- 1-based, two-digit format (`01`, `02`, …) matching Stage badges.
- Surface in both registry (headless) and SwiftUI (headed).

### Never do
- Resolve the source-display label by name — index is the SSOT (matches Stage badges).

## Success Criteria

- [ ] HeadlessMirrorTagTests passes both cases.
- [ ] Full suite green; release build clean.
