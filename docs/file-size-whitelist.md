# File-size whitelist

`scripts/lint-file-size.sh` rejects any `Sources/**/*.swift` file > 150 lines (per CLAUDE.md "SUPER MODULAR"). Files listed here are temporarily exempt while refactoring is queued.

**Discipline.** Every line below MUST link to a tracking issue. Removing a row is a green refactor; adding one (an exception for new code) requires explicit user approval.

## Format

One filename per line, comment with `#` mentions the tracking issue.

```
Sources/Path/To/File.swift   # see #N — backlog: split into <suggested>
```

## Backlog (refactor candidates carried into v1.0.0 ship cycle)

Sources/WDMCore/EDID.swift                        # 203 lines — split EDID parser, formatter, hasher into separate files (refactor backlog)
Sources/WDMSystem/FixtureDisplayProvider.swift    # 305 lines — split per protocol (snapshot, mutate, modes) (refactor backlog)
Sources/WDMSystem/VirtualCursorEdgeWarper.swift   # 206 lines — split tap-handler from geometry math (refactor backlog)
Sources/WDMSystem/AppKitOverlayFlipper.swift      # 339 lines — split FrameSink, window-retire, signal-handlers (refactor backlog)
Sources/WDMSystem/NativeStreamer.swift            # 256 lines — split StreamWriter from configuration plumbing (refactor backlog)
Sources/WDMSystem/AppKitPipFlipper.swift          # 315 lines — same shape as overlay flipper (refactor backlog)
Sources/WDMSystem/CGDisplayProvider.swift         # 266 lines — split snapshot, mode, mirror, IOKit-bridge (refactor backlog)
Sources/WDMCLI/Runner/CLIRunner.swift             # 170 lines — split argv parser from dispatch table (refactor backlog)
Sources/WDMCLI/Commands/VirtualCommand.swift      # 250 lines — split sub-verbs (create/list/remove) into separate Command files (refactor backlog)
Sources/WDMCLI/Commands/StreamCommand.swift       # 151 lines — borderline; one-line over (refactor backlog)
Sources/WDMKit/Safety/NativePopupConfirmer.swift  # 297 lines — split popup view from countdown timer (refactor backlog)
Sources/WDMKit/Format/ManpageFormatter.swift      # 250 lines — extract header generator (refactor backlog)

## Rationale

The lint is in place to prevent NEW oversize files. Existing offenders are tracked here so the v1.0.0 ship target isn't blocked on a 16-file refactor sweep. Each row removed is one less DRY/clarity defect.
