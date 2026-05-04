import SwiftUI

/// Center column. The spatial canvas where displays are arranged in a
/// shared coordinate space. M2 ships a placeholder canvas that lays out
/// the displays as flat rectangles using their current arrangement
/// `origin`. Drag-to-rearrange comes in Epic 4 (T4.x), but the canvas
/// already paints from the same VM data and is e2e-discoverable via
/// `.remoteID = stage.tile.<id>`.
public struct StageView: View {
    @ObservedObject var vm: DisplaysListVM
    let onSelect: (String) -> Void

    public init(vm: DisplaysListVM, onSelect: @escaping (String) -> Void) {
        self.vm = vm
        self.onSelect = onSelect
    }

    public var body: some View {
        GeometryReader { geo in
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
                    HStack(spacing: 18) {
                        ForEach(vm.tiles) { tile in
                            stageTile(for: tile)
                        }
                    }
                    .padding(36)
                }
            }
        }
    }

    private func stageTile(for tile: DisplaysListVM.Tile) -> some View {
        Button { onSelect(tile.remoteID) } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(tileShortLabel(tile))
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background {
                            Capsule().fill(.green.opacity(0.22))
                        }
                        .foregroundStyle(.green)
                    Spacer()
                }
                Spacer()
                Text(tileShortLabel(tile)).font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
                Text("\(tile.subtitle)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(14)
            .frame(width: 200, height: 160)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.black.opacity(0.30))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(tile.isSelected ? Color.green : .white.opacity(0.10),
                            lineWidth: tile.isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("stage.tile.\(tile.displayID)")
    }

    private func tileShortLabel(_ tile: DisplaysListVM.Tile) -> String {
        String(format: "%02d", tile.displayID)
    }
}
