# Function-size whitelist

`scripts/lint-function-size.sh` rejects any Swift function / init / deinit > 30 lines (per CLAUDE.md "SUPER MODULAR"). Functions listed here are temporarily exempt while refactoring is queued.

## Format

`<path>:<func-name>` per line. The lint reads only lines starting with `Sources/`.

## Backlog

Sources/WDMCore/EDID.swift:sha256                                   # crypto inline; refactor when EDID.swift is split
Sources/WDMCore/EDIDHasher.swift:sha256                              # crypto inline; refactor when split
Sources/WDMKit/Daemon/LaunchAgentInstaller.swift:plistContents       # plist template
Sources/WDMKit/Operations/WDMControllerCursorWrap.swift:cursorWrap   # cursor warp dispatch
Sources/WDMKit/Profiles/ProfileApplier.swift:apply                    # multi-step profile application
Sources/WDMKit/Safety/NativePopupConfirmer.swift:runOnMain           # main-actor popup runner
Sources/WDMCLI/Commands/HDRCommand.swift:run                        # 30+ lines — split arg parsing from controller call
Sources/WDMCLI/Commands/StreamCommand.swift:run                     # 30+ lines — split arg parsing
Sources/WDMCLI/Commands/StreamCommand.swift:parseOptions            # parser concentration; will split when StreamCommand is broken up
Sources/WDMCLI/Runner/CLIRunner.swift:run                           # dispatch table; will split with CLIRunner refactor
Sources/WDMCore/EDID.swift:parse                                    # EDID parser — refactor candidate when EDID.swift is split
Sources/WDMKit/Format/HumanFormatter.swift:displayBlock              # multi-line formatter
Sources/WDMKit/Format/ManpageFormatter.swift:render                  # template assembly
Sources/WDMKit/Format/CompletionsFormatter.swift:zsh                 # zsh template
Sources/WDMKit/Format/CompletionsFormatter.swift:bash                # bash template
Sources/WDMKit/Operations/WDMControllerArrangement.swift:setArrangement  # complex multi-step
Sources/WDMKit/Operations/WDMControllerCapture.swift:record           # capture pipeline
Sources/WDMKit/Safety/CountdownConfirmer.swift:confirm                # countdown loop
Sources/WDMKit/Safety/NativePopupConfirmer.swift:show                 # AppKit popup assembly
Sources/WDMMac/ViewModels/DisplaysListVM.swift:applyFlip              # task-detached lifecycle
Sources/WDMMac/Views/Inspector/InspectorBrightness.swift:body         # SwiftUI body — composition
Sources/WDMMacRemote/AccessibilityWalker.swift:walk                   # AX tree walker — recursive
Sources/WDMMacRemote/WDMMacRemoteAdapter.swift:dispatch               # action dispatch table
Sources/WDMMacRemote/WDMMacRemoteAdapter.swift:screenshot             # screenshot lifecycle
Sources/WDMMacRemote/WDMMacRemoteRunner.swift:sync                    # registry-rebuild monolith — top refactor target
Sources/WDMRemoteControl/Codec/RemoteActionJSON.swift:decode          # JSON dispatch
Sources/WDMSystem/AXWindowMover.swift:move                            # multi-step AX assembly
Sources/WDMSystem/AXWindowMover.swift:focus                           # AX focus dance
Sources/WDMSystem/AXWindowMover.swift:tileAcross                      # tile layout math
Sources/WDMSystem/AppKitOverlayFlipper.swift:run                      # RunLoop pump body
Sources/WDMSystem/AppKitOverlayFlipper.swift:startStream              # SCStream config + window assembly
Sources/WDMSystem/AppKitOverlayFlipper.swift:teardown                 # window/stream/cursor restore
Sources/WDMSystem/AppKitPipFlipper.swift:run                          # parallels overlay flipper
Sources/WDMSystem/AppKitPipFlipper.swift:startStream                  # parallels overlay flipper
Sources/WDMSystem/AppKitPipFlipper.swift:compositeCursor              # cursor compositing
Sources/WDMSystem/CGDisplayProvider.swift:setMirror                   # mirror config dance
Sources/WDMSystem/CGVirtualDisplayManager.swift:run                   # CGVirtualDisplay SPI dance
Sources/WDMSystem/CyclicArrangementWarper.swift:cyclicWarpTarget      # arrangement geometry
Sources/WDMSystem/FixtureDisplayProvider.swift:unmirror               # fixture mirror tracking
Sources/WDMSystem/IOKitEDID.swift:framebufferService                  # IOKit service search
Sources/WDMSystem/IOKitRotation.swift:framebufferService              # IOKit service search
Sources/WDMSystem/NativeStreamer.swift:stream                         # AVAssetWriter setup
Sources/WDMSystem/NativeStreamer.swift:runStream                      # AVAssetWriter run loop
Sources/WDMSystem/VirtualCursorEdgeWarper.swift:loop                  # event-tap loop body
Sources/WDMSystem/VirtualCursorEdgeWarper.swift:adjacentWarp          # geometry math
Sources/WDMWeb/Handlers/WDMWebIndexHandler.swift:template             # HTML template
Sources/WDMWeb/WDMWebMain.swift:run                                   # signal handlers + listener wiring

## Rationale

The lint catches NEW oversize functions. Each row removed is one less DRY/clarity defect. Same playbook as `docs/file-size-whitelist.md`.
