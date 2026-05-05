import SwiftUI
import WDMCore

/// GEOMETRY section — rotation row (0 / 90 / 180 / 270°) + flip row
/// (— / Flip H / Flip V). Both rows reuse the same `SegmentedRow`
/// primitive — DRY. State lives on the VM (per-tile), not in @State,
/// so the pip survives selection changes (render-layer rule).
public struct InspectorGeometry: View {
    @ObservedObject var vm: DisplaysListVM
    let tile: DisplaysListVM.Tile

    public init(vm: DisplaysListVM, tile: DisplaysListVM.Tile) {
        self.vm = vm
        self.tile = tile
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SegmentedRow(
                segments: [0, 90, 180, 270].map {
                    .init(id: $0, label: "\($0)°", remoteID: "inspector.rotate.\($0)")
                },
                selected: tile.rotationDegrees
            ) { vm.setRotation(displayID: tile.displayID, degrees: $0) }

            SegmentedRow(
                segments: Self.flipSegments,
                selected: vm.flip(forRemoteID: tile.remoteID)
            ) { vm.applyFlip(displayID: tile.displayID, flip: $0) }

            // Honest unsupported-path: when rotate / flip fails (Apple
            // Silicon built-in refuses rotation, or Screen Recording
            // permission is needed for the flip overlay), the user must
            // SEE why — not stare at an unchanged screen.
            if let err = vm.lastError, !err.isEmpty {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(3)
                    .accessibilityIdentifier("inspector.geometry.lastError")
                    .padding(.top, 2)
            }
        }
    }

    private static let flipSegments: [SegmentedRow<Flip>.Segment] = [
        .init(id: .none, label: "—", remoteID: "inspector.flip.none"),
        .init(id: .horizontal, label: "Flip H", remoteID: "inspector.flip.h"),
        .init(id: .vertical, label: "Flip V", remoteID: "inspector.flip.v"),
    ]
}
