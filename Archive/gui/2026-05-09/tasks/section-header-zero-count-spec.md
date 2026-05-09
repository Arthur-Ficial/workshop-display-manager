# Spec: SectionHeader hides count chip when count is 0

> Tiny visual-debt fix under parent SPEC.md. Was previously committed
> as a one-line patch without TDD discipline; reverted and being
> redone via the agent-skills workflow.

## Assumptions

1. `nil` count remains "no chip at all" (existing behavior).
2. `count == 0` should now also render no chip, matching the design briefing's empty-state treatment ("no virtual displays" hint communicates the zero already).
3. `count >= 1` continues to render the chip.

→ Correct now or these stand.

## Objective

Empty sidebar sections (VIRTUAL when no virtual displays exist, PROFILES when no profiles saved yet) should not show a redundant `0` chip. The chip is signal-when-non-zero; when zero, the empty-state hint already communicates the count.

## Code Style

```swift
// SectionHeader body
if let count, count > 0 { CountChip(count: count) }
```

## Testing Strategy

- Unit test in `Tests/WDMMacRemoteTests/` (no need for e2e — pure SwiftUI render predicate). Asserts the rule via the SectionHeader view body — that we exercise the `count > 0` branch with a concrete scene tree.
- Headed visual e2e via `tinyscreenshot` after restart, captured manually as proof.

## Boundaries

### Always do
- Treat `nil` and `0` identically — both hide the chip.
- Pin the rule with a unit test so any future regression is caught at `swift test` time.

### Ask first
- Adding a custom "Empty" presentation token (out of scope; the existing EmptyHint covers it).

### Never do
- Render `0` as a chip. Visual debt was the user-reported symptom.

## Success Criteria

- [ ] New test asserts: count=0 → no chip rendered; count=3 → chip rendered.
- [ ] tinyscreenshot of headed wdm-mac shows VIRTUAL header without `0` chip.
- [ ] Full suite green; release build clean.
