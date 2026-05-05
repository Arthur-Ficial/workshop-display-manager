import SwiftUI

/// BRIGHTNESS section — slider 0..1 for displays where the value is
/// readable, single-line refusal hint where it isn't (most external
/// monitors). The headless registry path in `WDMMacRemoteRunner`
/// surfaces the same state via `inspector.brightness.value` /
/// `.unavailable` so AI agents see what humans see.
///
/// **Reactive write — every slider tick changes the screen.** Mirrors
/// macOS System Settings → Displays → Brightness; the user expects
/// the screen to brighten/dim under their fingertip, not on
/// drag-release. `controller.brightness(_:value:confirmer:)` is fast
/// enough (one DisplayServices call, AutoYesConfirmer no-op) that
/// 60 Hz drag updates cost ~180 ms/sec total — well under any
/// noticeable budget. If profiling ever finds otherwise, throttle
/// here, don't break responsiveness.
public struct InspectorBrightness: View {
    @ObservedObject var vm: DisplaysListVM
    let tile: DisplaysListVM.Tile

    public init(vm: DisplaysListVM, tile: DisplaysListVM.Tile) {
        self.vm = vm
        self.tile = tile
    }

    public var body: some View {
        if let level = tile.brightness {
            HStack(spacing: 8) {
                Image(systemName: "sun.min")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Slider(value: Binding(
                    get: { Double(level) },
                    set: { vm.setBrightness(displayID: tile.displayID, value: Float($0)) }
                ), in: 0...1)
                .accessibilityIdentifier("inspector.brightness.slider")
                Image(systemName: "sun.max")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        } else {
            Text("Brightness control unavailable on this display.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("inspector.brightness.unavailable")
        }
    }
}
