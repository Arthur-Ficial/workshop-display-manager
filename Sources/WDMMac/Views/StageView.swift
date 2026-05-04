import SwiftUI

/// Center column. The spatial canvas where displays are arranged.
/// Tiles are chassis-shaped (laptop / external monitor) per the
/// design briefing — pure render layer; data comes from the VM.
public struct StageView: View {
    @ObservedObject var vm: DisplaysListVM
    let onSelect: (String) -> Void

    public init(vm: DisplaysListVM, onSelect: @escaping (String) -> Void) {
        self.vm = vm
        self.onSelect = onSelect
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.black.opacity(0.18))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.06), lineWidth: 1)
                }

            if vm.tiles.isEmpty {
                Text("No displays detected.")
                    .foregroundStyle(.secondary)
            } else {
                HStack(alignment: .center, spacing: 24) {
                    ForEach(vm.tiles) { tile in
                        StageTileView(
                            title: tile.title,
                            subtitle: tile.subtitle,
                            badge: String(format: "%02d", tile.displayID),
                            isSelected: tile.isSelected,
                            kind: tile.isMain ? .laptop : .monitor,
                            remoteID: "stage.tile.\(tile.displayID)"
                        ) { onSelect(tile.remoteID) }
                    }
                }
                .padding(36)
            }
        }
    }
}
