import SwiftUI

/// One display in the sidebar's DISPLAYS section. Selection highlight
/// matches the design briefing's green-tinted active row treatment.
public struct SidebarDisplayRow: View {
    let tile: DisplaysListVM.Tile
    let isSelected: Bool
    let onSelect: (String) -> Void

    public init(tile: DisplaysListVM.Tile, isSelected: Bool,
                onSelect: @escaping (String) -> Void) {
        self.tile = tile
        self.isSelected = isSelected
        self.onSelect = onSelect
    }

    public var body: some View {
        Button { onSelect(tile.remoteID) } label: {
            HStack(spacing: 10) {
                Image(systemName: tile.isMain ? "laptopcomputer" : "display")
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? .green : .secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(tile.title).font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    Text(tile.subtitle).font(.system(size: 10))
                        .foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                if tile.isMain { Badge("MAIN") }
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .clickable(isSelected: isSelected)
        .overlay(alignment: .leading) {
            // Left-edge tick — kept as a separate accent on top of the
            // shared chrome so the selected row still has its design pip.
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(isSelected ? Color.green : .clear)
                .frame(width: 3, height: 22)
                .offset(x: -2)
        }
        .accessibilityIdentifier(tile.remoteID)
    }
}
