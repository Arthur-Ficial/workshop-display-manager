import SwiftUI

/// Top of the inspector: eyebrow tag (BUILT-IN / EXTERNAL DISPLAY / …),
/// display name, and status badges (Main, Mirror of, REC, Headless, HDR).
public struct InspectorHeader: View {
    let tile: DisplaysListVM.Tile
    let allTiles: [DisplaysListVM.Tile]

    public init(tile: DisplaysListVM.Tile, allTiles: [DisplaysListVM.Tile] = []) {
        self.tile = tile
        self.allTiles = allTiles
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(tile.isMain ? "BUILT-IN" : "EXTERNAL DISPLAY")
            Text(tile.title).font(.system(size: 22, weight: .semibold))
                .lineLimit(2)
                .accessibilityIdentifier("inspector.title")
            HStack(spacing: 6) {
                if tile.isMain { Badge("Main") }
                if let label = mirrorOfLabel {
                    Badge(label).accessibilityIdentifier("inspector.title.mirror")
                }
            }
        }
    }

    private var mirrorOfLabel: String? {
        guard let src = tile.mirrorSource,
              let idx = allTiles.firstIndex(where: { $0.displayID == src })
        else { return nil }
        return String(format: "Mirror of %02d", idx + 1)
    }
}
