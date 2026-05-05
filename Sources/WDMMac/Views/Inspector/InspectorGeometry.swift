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
        VStack(spacing: 8) {
            SegmentedRow(
                segments: [0, 90, 180, 270].map {
                    .init(id: $0, label: "\($0)°", remoteID: "inspector.rotate.\($0)")
                },
                selected: tile.rotationDegrees
            ) { _ in
                // Apply landed in a later milestone — for M2 the controller
                // doesn't write rotation from the GUI yet. Click is wired so
                // the remote API + e2e coverage exercises the segment.
            }

            SegmentedRow(
                segments: Self.flipSegments,
                selected: vm.flip(forRemoteID: tile.remoteID)
            ) { vm.setFlip($0, forRemoteID: tile.remoteID) }
        }
    }

    private static let flipSegments: [SegmentedRow<Flip>.Segment] = [
        .init(id: .none, label: "—", remoteID: "inspector.flip.none"),
        .init(id: .horizontal, label: "Flip H", remoteID: "inspector.flip.h"),
        .init(id: .vertical, label: "Flip V", remoteID: "inspector.flip.v"),
    ]
}
