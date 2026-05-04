import SwiftUI

/// Top of the inspector: eyebrow tag (BUILT-IN / EXTERNAL DISPLAY / …),
/// display name, and status badges (Main, Mirror of, REC, Headless, HDR).
public struct InspectorHeader: View {
    let tile: DisplaysListVM.Tile
    public init(tile: DisplaysListVM.Tile) { self.tile = tile }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(tile.isMain ? "BUILT-IN" : "EXTERNAL DISPLAY")
            Text(tile.title).font(.system(size: 22, weight: .semibold))
                .lineLimit(2)
                .accessibilityIdentifier("inspector.title")
            if tile.isMain { Badge("Main") }
        }
    }
}
