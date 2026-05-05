# Spec: VIRTUAL sidebar section matches PROFILES bottom-CTA pattern

> User-reported visual inconsistency 2026-05-05 with screenshot:
> "why does this have 2 different UIs? is this really like specified
> in the document briefing? i like the profile one better!"
>
> Design briefing concurs:
> > "Bottom of the section: one CTA — **+ Add virtual display**."

## Assumptions

1. The VIRTUAL `+` button moves from the section header (heavy outlined) to a bottom-of-section CTA "+ Add virtual display" — same shape as PROFILES' "+ Save current as…".
2. The button currently has an empty action (`Button {} label:`) — a fake clickable per CLAUDE.md "no fakes". Click action becomes an *honest refusal*: sets `vm.lastError` to a clear message that virtual-display creation isn't wired through the GUI yet. The CLI's `wdm virtual create` is the supported path.
3. `sidebar.virtual.add` remoteID stays stable.
4. Headless registry gains a `sidebar.virtual.add` entry so the headless e2e can drive it (today only the SwiftUI AX side carries the ID).

## Objective

Sidebar visual symmetry — VIRTUAL and PROFILES sections both use the bottom-CTA pattern from the design briefing. Click on the VIRTUAL CTA gives an honest refusal (not a silent no-op).

## Project Structure

```
Sources/WDMMac/Views/SidebarView.swift             refactor virtualSection: header without trailing, bottom "+ Add virtual display" CTA
Sources/WDMMac/ViewModels/DisplaysListVM.swift     +`refuseVirtualCreate()` — sets lastError to honest refusal message
Sources/WDMMacRemote/WDMMacRemoteRunner.swift      register `sidebar.virtual.add` so headless tests can drive it
Tests/WDMMacE2ETests/HeadlessVirtualTests.swift    NEW. Asserts: registry exposes sidebar.virtual.add; click sets lastError to refusal message; ID stable
```

## Testing Strategy

- **Headless e2e** (default-runs):
  - Snapshot exposes `sidebar.virtual.add` (currently absent → RED)
  - Clicking it produces an observable side effect — vm.lastError becomes a non-empty string with refusal text. We need a way to read lastError from the test… either expose a `/ui/state` endpoint or assert the same intent via a new VM-level entry. Simplest: add a passive registry node `sidebar.virtual.lastError` that surfaces vm.lastError when non-empty. Test clicks the button, snapshots, asserts the error node appears with the refusal message.
- **Visual proof** via tinyscreenshot of headed wdm-mac after restart.

## Boundaries

### Always do
- Honest refusal — clicking the button must produce an observable state change (lastError set). No silent no-ops.
- Stable remoteID across the rename.

### Ask first
- Wiring real virtual-display creation through the GUI (out of scope; CGVirtualDisplay SPI work, naming UI, etc.).

### Never do
- Leave the empty `Button {} label:` no-op in production code.
- Hide the unsupported state — refusal is visible.

## Success Criteria

- [ ] VIRTUAL section matches PROFILES visually: simple header (no trailing button), bottom "+ Add virtual display" CTA.
- [ ] Headless test asserts: registry exposes `sidebar.virtual.add`; click → `sidebar.virtual.lastError` text appears with the refusal message.
- [ ] Visual proof: tinyscreenshot of headed wdm-mac shows the bottom CTA pattern in both VIRTUAL and PROFILES sections.
- [ ] Full suite green; release clean; lint clean.
