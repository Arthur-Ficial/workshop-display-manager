# Spec: WDMMac Sidebar — Profile row delete

> Feature-level spec under parent `SPEC.md`. Closes one item from
> `tasks/todo.md`. Pairs with the existing save (`+`) and restore
> (row click) verbs already shipped — completes profile lifecycle in
> the GUI.

## Assumptions

1. Per-row delete affordance, not a confirmation dialog. Workshop facilitator wants speed; misclicks are recoverable from `wdm save` plus the daemon's `last.json`.
2. Stable remoteID `sidebar.profiles.row.<name>.delete`.
3. Reuses `controller.removeProfile(_:)` (CLI's `wdm profiles remove <name>` — same Kit op).
4. After delete, `vm.reloadProfiles()` re-renders the sidebar; the row disappears in the next snapshot version.

→ Correct now or these stand.

## Objective

A workshop facilitator can delete a saved profile (especially auto-named `snapshot-*`) directly from the sidebar without dropping to the CLI. One click → row gone, file gone. Same Kit op the CLI exposes.

## Project Structure

```
Sources/WDMMac/Views/SidebarView.swift                  +1 button per row, accessibilityIdentifier "sidebar.profiles.row.<name>.delete"
Sources/WDMMac/ViewModels/DisplaysListVM.swift          +`removeProfile(named name: String)`
Sources/WDMMacRemote/WDMMacRemoteRunner.swift           registers one delete entry per profile
Tests/WDMMacE2ETests/HeadlessProfilesTests.swift        +clickingProfileRowDeleteRemovesIt
Tests/WDMMacE2ETests/HeadedBrightnessTests.swift        (no change; this feature gets its own headed coverage in HeadlessProfilesTests' headed sibling — see below)
Tests/WDMMacE2ETests/HeadedProfilesTests.swift          NEW — visual headed e2e per SPEC.md "Always do" rule
```

## Code Style

```swift
public func removeProfile(named name: String) {
    do { try controller.removeProfile(name); lastError = nil }
    catch { lastError = "\(error)" }
    reloadProfiles()
}
```

## Testing Strategy

- Headless e2e (`HeadlessProfilesTests.clickingProfileRowDeleteRemovesIt`):
  pre-seed two profiles, click `sidebar.profiles.row.<name>.delete`,
  wait, assert (a) on-disk JSON file is gone, (b) row is absent from
  next snapshot.
- Headed e2e (`HeadedProfilesTests.deleteRowVisibleInAXTree`): spawn
  fresh wdm-mac with a seeded profile, GET snapshot, assert the
  delete row is in the AX tree, click it, assert next snapshot has
  no delete row.

## Boundaries

### Always do
- Route through `controller.removeProfile`. Frontend never touches `provider.*` or the file system directly.
- Stable `.delete` remoteIDs covered by an actual click in tests.

### Ask first
- Confirmation dialog (don't add — speed matters; not asking for now).

### Never do
- Use `FileManager.removeItem` from VM/View. Kit op is the only path.
- Render a delete button for the empty state.

## Success Criteria

- [ ] HeadlessProfilesTests passes the new case.
- [ ] HeadedProfilesTests visible-headed e2e runs and passes against a fresh wdm-mac (`WDM_HEADED_E2E=1 swift test --filter HeadedProfilesTests`).
- [ ] Full suite green; release build clean; lint clean.
