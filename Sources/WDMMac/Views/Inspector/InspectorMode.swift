import SwiftUI

/// MODE section — current resolution × refresh + HiDPI scale + chevron.
/// Real dropdown (with full mode list) lands in T5.5; for M2 it shows
/// the current mode as a non-interactive button shape so the design is
/// pixel-correct.
public struct InspectorMode: View {
    let tile: DisplaysListVM.Tile
    public init(tile: DisplaysListVM.Tile) { self.tile = tile }

    public var body: some View {
        Button {} label: {
            HStack {
                Text(tile.subtitle).font(.system(size: 13, weight: .medium))
                Spacer()
                Text("@1x").font(.caption).foregroundStyle(.secondary)
                Image(systemName: "chevron.down").font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .clickable(cornerRadius: 8)
        .accessibilityIdentifier("inspector.mode.dropdown")
    }
}
