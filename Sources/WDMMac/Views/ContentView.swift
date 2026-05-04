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
        ZStack {
            // Faux-Tahoe atmospheric backdrop (the chrome behind the glass).
            LinearGradient(
                colors: [Color(.sRGB, red: 0.94, green: 0.95, blue: 0.97, opacity: 1),
                         Color(.sRGB, red: 0.86, green: 0.89, blue: 0.94, opacity: 1)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ).ignoresSafeArea()

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
        }
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
