import SwiftUI

/// One display in the sidebar's DISPLAYS section. Selection highlight
/// matches the design briefing's green-tinted active row treatment.
public struct SidebarDisplayRow: View {
    let tile: DisplaysListVM.Tile
    let onSelect: (String) -> Void

    public init(tile: DisplaysListVM.Tile, onSelect: @escaping (String) -> Void) {
        self.tile = tile
        self.onSelect = onSelect
    }

    public var body: some View {
        Button { onSelect(tile.remoteID) } label: {
            HStack(spacing: 10) {
                Image(systemName: tile.isMain ? "laptopcomputer" : "display")
                    .font(.system(size: 14))
                    .foregroundStyle(tile.isSelected ? .green : .secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(tile.title).font(.system(size: 13, weight: .medium))
                        .foregroundStyle(tile.isSelected ? .primary : .primary)
                        .lineLimit(1)
                    Text(tile.subtitle).font(.system(size: 10))
                        .foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                if tile.isMain { Badge("MAIN") }
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(tile.isSelected ? Color.green.opacity(0.18) : .clear)
            }
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(tile.isSelected ? Color.green : .clear)
                    .frame(width: 3, height: 22)
                    .offset(x: -2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(tile.remoteID)
    }
}
