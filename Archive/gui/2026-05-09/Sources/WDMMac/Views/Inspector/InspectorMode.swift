import SwiftUI
import WDMCore

/// MODE section — current resolution × refresh + HiDPI scale + chevron.
/// Real Menu populated from `controller.modes(displayID)`. Selecting a
/// mode routes through `vm.setMode(displayID:mode:)` (Task.detached +
/// SafeTxVM banner for revert), same Kit op as `wdm mode <id> WxH@Hz`.
public struct InspectorMode: View {
    @ObservedObject var vm: DisplaysListVM
    let tile: DisplaysListVM.Tile

    public init(vm: DisplaysListVM, tile: DisplaysListVM.Tile) {
        self.vm = vm
        self.tile = tile
    }

    public var body: some View {
        Menu {
            ForEach(vm.availableModes(displayID: tile.displayID), id: \.self) { mode in
                Button(label(for: mode)) {
                    vm.setMode(displayID: tile.displayID, mode: mode)
                }
            }
        } label: {
            HStack {
                Text(tile.subtitle).font(.system(size: 13, weight: .medium))
                Spacer()
                Text("@1x").font(.caption).foregroundStyle(.secondary)
                Image(systemName: "chevron.down").font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .clickable(cornerRadius: 8)
        .accessibilityIdentifier("inspector.mode.dropdown")
    }

    private func label(for mode: Mode) -> String {
        "\(mode.width)×\(mode.height) @ \(Int(mode.refreshHz))Hz"
    }
}
