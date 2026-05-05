import SwiftUI

/// ACTIONS section — five rows. Make Main is wired to the live Kit
/// op (`controller.main`); the other four refuse honestly with a CLI
/// equivalent (per CLAUDE.md "no fakes — surface the limitation").
public struct InspectorActions: View {
    @ObservedObject var vm: DisplaysListVM
    let tile: DisplaysListVM.Tile

    public init(vm: DisplaysListVM, tile: DisplaysListVM.Tile) {
        self.vm = vm; self.tile = tile
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ActionRow(label: "Make main", symbol: "star",
                      remoteID: "inspector.action.makeMain") {
                vm.makeMain(displayID: tile.displayID)
            }
            ActionRow(label: "Open PiP window", symbol: "pip",
                      remoteID: "inspector.action.pip") {
                vm.refuseAction(named: "PiP window",
                                cliEquivalent: "wdm pip \(tile.displayID)")
            }
            ActionRow(label: "Record", symbol: "record.circle",
                      remoteID: "inspector.action.record") {
                vm.refuseAction(named: "Record",
                                cliEquivalent: "wdm record \(tile.displayID) --out <path> --duration <sec>")
            }
            ActionRow(label: "Reset / reconnect…", symbol: "arrow.clockwise",
                      remoteID: "inspector.action.reset") {
                vm.refuseAction(named: "Reset",
                                cliEquivalent: "wdm doctor disconnect \(tile.displayID)")
            }
            ActionRow(label: "Open Advanced", symbol: "slider.horizontal.3",
                      remoteID: "inspector.action.advanced") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
        }
    }
}
