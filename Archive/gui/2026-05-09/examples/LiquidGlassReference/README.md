# Liquid Glass Reference

A 50-line minimal SwiftUI App that renders authentic Tahoe Liquid Glass.
Use as a **reference** when wdm-mac doesn't look right — if this demo
shows real glass and your code doesn't, the difference is the bug.

## Run

```sh
cd examples/LiquidGlassReference
swift run -c release LiquidGlassDemo
```

## What this proves

- `swift-tools-version: 6.2` + `.macOS(.v26)` deployment target → binary
  has `LC_BUILD_VERSION minos 26.0` (verify with `otool -l`).
- SwiftUI App + `WindowGroup` + macOS 26 SDK = Tahoe Liquid Glass chrome
  automatically. No NSWindow ceremony required for the App-lifecycle path.
- `.glassEffect(in:)`, `.glassEffect(.regular.tint(...).interactive())`,
  `GlassEffectContainer`, `.buttonStyle(.glass)`, `.buttonStyle(.glassProminent)`
  — the four primitives.
- A vivid backdrop (LinearGradient) makes the frost visible. Glass on a
  solid colour just looks like a slight tint.

## What's NOT in this demo

- Bundling as `.app` with `Info.plist` (`scripts/bundle-wdm-mac.sh` does that).
- Manual `NSWindow` integration (see `Sources/WDMMacRemote/HeadedRunner.swift`).
- Remote-control wiring (the entire Epic 17 lives in `Sources/WDMRemoteControl`).
