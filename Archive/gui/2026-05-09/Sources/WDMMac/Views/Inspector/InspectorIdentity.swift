import SwiftUI

/// IDENTITY section — five KV rows: vendor / model / serial / cgID / alias.
/// Real values come from CGDisplay vendor IDs in T5.9; for M2 we show
/// what we have (cgID is real, alias is the display name lower-cased).
public struct InspectorIdentity: View {
    let tile: DisplaysListVM.Tile
    public init(tile: DisplaysListVM.Tile) { self.tile = tile }

    public var body: some View {
        VStack(spacing: 6) {
            KVRow("vendor", "—")
            KVRow("model", tile.title)
            KVRow("serial", "—")
            KVRow("cgID", "0x" + String(tile.displayID, radix: 16, uppercase: true))
            KVRow("alias", tile.title.lowercased())
        }
    }
}
