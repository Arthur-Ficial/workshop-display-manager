# Cyclomatic-complexity whitelist

`scripts/lint-cyclomatic-complexity.sh` rejects any Swift function with branch count > 7. Functions listed here are temporarily exempt while refactoring is queued. Same playbook as `docs/file-size-whitelist.md` and `docs/function-size-whitelist.md`.

## Format

`<path>:<func-name>` per line, leading `Sources/`.

## Backlog
Sources/WDMCLI/Commands/DDCCommand.swift:run
Sources/WDMCLI/Commands/GetCommand.swift:parse
Sources/WDMCLI/Commands/GetCommand.swift:text
Sources/WDMCLI/Commands/HDRCommand.swift:run
Sources/WDMCLI/Commands/HotkeysCommand.swift:run
Sources/WDMCLI/Commands/StreamCommand.swift:run
Sources/WDMCLI/Commands/StreamCommand.swift:parseOptions
Sources/WDMCLI/Commands/VirtualCommand.swift:run
Sources/WDMCLI/Runner/CLIRunner.swift:run
Sources/WDMCLI/Runner/CLIRunner.swift:handleProviderError
Sources/WDMCore/EDID.swift:sha256
Sources/WDMCore/EDIDHasher.swift:sha256
Sources/WDMCore/Flip+Toggle.swift:toggling
Sources/WDMCore/Flip+Toggle.swift:hasAxis
Sources/WDMKit/Format/ManpageFormatter.swift:render
Sources/WDMKit/Hotkeys/HotkeyRegistrarFactory.swift:make
Sources/WDMKit/Operations/WDMControllerPrivate.swift:map
Sources/WDMKit/Operations/WDMFieldValueFactory.swift:fieldValue
Sources/WDMKit/Profiles/ProfileApplier.swift:apply
Sources/WDMKit/Safety/NativePopupConfirmer.swift:runOnMain
Sources/WDMMacRemote/AccessibilityWalker.swift:walk
Sources/WDMMacRemote/AccessibilityWalker.swift:shortRole
Sources/WDMMacRemote/MacArgs.swift:parse
Sources/WDMMacRemote/WDMMacRemoteAdapter.swift:keystroke
Sources/WDMMacRemote/WDMMacRemoteAdapter.swift:screenshot
Sources/WDMMacRemote/WDMMacRemoteAdapter.swift:virtualKeyCode
Sources/WDMRemoteControl/Codec/RemoteActionJSON.swift:decode
Sources/WDMRemoteControl/HTTP/RemoteResponse.swift:reason
Sources/WDMRemoteControl/Server/RemoteControlRoutes.swift:dispatch
Sources/WDMSystem/AXWindowMover.swift:focus
Sources/WDMSystem/AXWindowMover.swift:tileAcross
Sources/WDMSystem/AppKitOverlayFlipper.swift:public
Sources/WDMSystem/AppKitOverlayFlipper.swift:startStream
Sources/WDMSystem/AppKitOverlayFlipper.swift:teardown
Sources/WDMSystem/AppKitPipFlipper.swift:public
Sources/WDMSystem/AppKitPipFlipper.swift:startStream
Sources/WDMSystem/CGDisplayEventStream.swift:translate
Sources/WDMSystem/CGVirtualDisplayManager.swift:run
Sources/WDMSystem/CGWindowLister.swift:public
Sources/WDMSystem/CarbonHotkeyRegistrar.swift:parse
Sources/WDMSystem/CyclicArrangementWarper.swift:cyclicWarpTarget
Sources/WDMSystem/DDCProvider.swift:code
Sources/WDMSystem/IOKitEDID.swift:framebufferService
Sources/WDMSystem/IOKitFlip.swift:encodeTransform
Sources/WDMSystem/IOKitFlip.swift:framebufferService
Sources/WDMSystem/IOKitRotation.swift:framebufferService
Sources/WDMSystem/NativeStreamer.swift:runStream
Sources/WDMWeb/HTTP/WDMWebResponse.swift:reasonPhrase
Sources/WDMWeb/Handlers/WDMWebHandlerSupport.swift:httpStatus
Sources/WDMWeb/WDMWebMain.swift:run
