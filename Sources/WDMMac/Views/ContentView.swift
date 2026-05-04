import SwiftUI

/// Root pane. Just composes the displays list inside a Liquid Glass panel
/// with a header. No business logic — the VM owns everything.
public struct ContentView: View {
    @ObservedObject var vm: DisplaysListVM
    let onSelect: (String) -> Void

    public init(vm: DisplaysListVM, onSelect: @escaping (String) -> Void) {
        self.vm = vm
        self.onSelect = onSelect
    }

    public var body: some View {
        // No opaque backdrop — HeadedRunner's NSVisualEffectView (material
        // .sidebar, blendingMode .behindWindow) supplies the half-transparent
        // frosted backdrop that shows the desktop through. SwiftUI content
        // sits on top; .glassEffect() on cards layers further glass on
        // whatever's behind the card (the desktop, blurred).
        VStack(spacing: 18) {
            HStack {
                Text("Workshop Display Manager")
                    .font(.system(size: 22, weight: .semibold))
                Spacer()
                Text("\(vm.tiles.count) display\(vm.tiles.count == 1 ? "" : "s")")
                    .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("titlebar")

            tilesContainer
                .accessibilityIdentifier("displays.list")

            Spacer()
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 360)
    }

    @ViewBuilder
    private var tilesContainer: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer {
                tilesPanel
            }
        } else {
            tilesPanel
        }
    }

    private var tilesPanel: some View {
        GlassPanel {
            if let err = vm.lastError {
                Text(err).foregroundStyle(.red)
                    .accessibilityIdentifier("displays.error")
            } else if vm.tiles.isEmpty {
                Text("No displays detected.")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("displays.empty")
            } else {
                VStack(spacing: 6) {
                    ForEach(vm.tiles) { tile in
                        DisplayTileView(
                            title: tile.title,
                            subtitle: tile.subtitle,
                            isMain: tile.isMain,
                            isSelected: tile.isSelected,
                            remoteID: tile.remoteID
                        ) { onSelect(tile.remoteID) }
                    }
                }
            }
        }
    }
}
