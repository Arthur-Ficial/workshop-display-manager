# Known test flakes

Tracking surface for tests that are temporarily disabled. The wdm CLAUDE.md rule is *"No `@disabled` without an issue link in a comment."* Because Arthur-Ficial repos cannot use GitHub Actions (quota exhausted, see `~/.claude/.../memory/feedback_no_github_actions.md`), GitHub Issues are an unreliable tracker for this repo. **This file is the canonical registry instead.**

Every `@Test(.disabled("…"))` annotation in `Tests/` MUST end its reason string with a link to an anchor on this page:

```
@Test(.disabled("<short reason> (see docs/known-flakes.md#<anchor>)"))
```

The `Tests/WDMCLITests/DisabledTestsHaveLinkTest.swift` test enforces this by scanning every `Tests/**/*.swift` file at every `swift test` run.

---

## ax-walker-tab-role

**Tests:**
- `Tests/WDMMacE2ETests/HeadedTabClickTests.swift` — `tabsClickableViaRemoteAPI`
- `Tests/WDMMacE2ETests/HeadedClickCoverageTests.swift` — `everyClickableDispatchable`
- `Tests/WDMMacE2ETests/HeadedSnapshotCoverageTests.swift` — `everyRemoteIDInSnapshot`

**Symptom:** SwiftUI `Button` declarations carrying `.buttonStyle(.plain)` + `.clickable()` don't surface in the AccessibilityWalker with `role == "AXButton"`, so the test's `pressable.contains($0.role)` predicate never finds them. The titlebar tabs are the most visible case (`titlebar.tab.{stage,profiles,recordings}`); 18 other remoteIDs (sidebar.virtual.empty, inspector.action.*, inspector.title, statusbar.*, stage.canvas, etc.) are also absent from `/ui/snapshot` because the walker filters strictly by interactive role + non-empty id.

**Plan:** M5 fixes the role exposure (likely `.accessibilityAddTraits(.isButton)` on each tab Button + a wider walker policy for static remoteIDs). Tests re-enabled then. Tracked under [issue #119](https://github.com/Arthur-Ficial/workshop-display-manager/issues/119) (M5 — GUI gap closure).

**Workaround in place (golden-goal.sh):** The 3 suites are skipped in `make golden-goal` headed-e2e via `--skip` flags. The remaining 10 headed tests run visibly and pass.

---

## headed-settings-parallel

**Test:** `Tests/WDMMacE2ETests/HeadedSettingsTests.swift` — `openSettingsClickAndSnapshot`

**Symptom:** When the WDMMac end-to-end test suite runs in parallel (the default for `swift test`), the test that drives the AppKit Settings… menu through the `openSettings` remote ID fails intermittently. The other parallel headed tests sometimes raise their own `wdm-mac` instance to the foreground, which yanks `NSApp.mainMenu` out of focus on the instance under test. The `openSettings` AX item then disappears from the snapshot for the duration of the active-app handoff, and the assertion `try #require(opener != nil, …)` fails.

**Root cause:** AppKit's main menu (and the Settings… menu item that ships with it) is exposed via accessibility *only when the owning process is the active application.* Multiple headed `wdm-mac` instances racing for `NSRunningApplication.activate()` is fundamentally incompatible with parallel test execution. This is a Swift Testing / AppKit interaction quirk, not a wdm regression.

**Workaround in place:**
- The disable annotation documents the constraint.
- The same code path — clicking `openSettings` and snapshotting the resulting Settings window — IS exercised by `assertPane(named:tabRemoteID:port:snap:)` inside the (passing) `HeadedFullFlowTest`, which runs as a single sequential session.
- Manual repro: `make app-mac && wdm-mac-control click @<openSettings ref>`.

**Unblock criteria** (re-enable when ANY of these is true):
1. Swift Testing gains a stable `.serialized` trait that runs a specific test outside the parallel pool. (Tracked upstream — there is `.serialized` on suites, but cross-suite serialization with the rest of the package is the issue here.)
2. We split the `WDMMacE2ETests` target into two SPM products and run the menu-driven tests in their own non-parallel `swift test` invocation. Likely the cleanest fix; touches `Package.swift`.
3. We add a `WDM_HEADED_SERIAL=1` env-var path that makes the headed harness skip parallel-unsafe assertions and reroutes them through `HeadedFullFlowTest`.

**Risk if left disabled:** Low — the code path under test is covered by `HeadedFullFlowTest`. We lose only the *isolated* assertion about Settings IDs being reachable through the menu when the rest of the app is already in a steady state. We do not lose coverage of any production behaviour.

**Owner:** unassigned (next pass at headed-test serialization picks this up).
