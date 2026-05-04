import SwiftUI

/// Right column. Shell that composes the per-display inspector sections.
/// Each section lives in its own file (InspectorMode/Identity/Geometry/
/// Actions) so they're each ≤30 LOC and testable in isolation.
public struct InspectorView: View {
    @ObservedObject var vm: DisplaysListVM

    public init(vm: DisplaysListVM) { self.vm = vm }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let tile = selectedTile {
                    InspectorHeader(tile: tile)
                    SectionLabel("MODE")
                    InspectorMode(tile: tile)
                    SectionLabel("IDENTITY")
                    InspectorIdentity(tile: tile)
                    SectionLabel("GEOMETRY")
                    InspectorGeometry()
                    SectionLabel("ACTIONS")
                    InspectorActions()
                } else {
                    Text("Select a display to inspect.")
                        .foregroundStyle(.secondary).padding(.top, 36)
                }
                Spacer()
            }
            .padding(18)
        }
        .frame(width: 280)
    }

    private var selectedTile: DisplaysListVM.Tile? {
        vm.tiles.first(where: \.isSelected) ?? vm.tiles.first
    }
}
