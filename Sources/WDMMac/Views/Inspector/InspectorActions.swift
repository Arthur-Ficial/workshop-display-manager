import SwiftUI
import AppKit
import UniformTypeIdentifiers

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
                vm.openPiP(sourceDisplayID: tile.displayID)
            }
            ActionRow(label: "Record", symbol: "record.circle",
                      remoteID: "inspector.action.record") {
                vm.startRecording(displayID: tile.displayID)
            }
            ActionRow(label: "Reset / reconnect…", symbol: "arrow.clockwise",
                      remoteID: "inspector.action.reset") {
                vm.resetDisplay(displayID: tile.displayID)
            }
            ActionRow(label: "Open Advanced", symbol: "slider.horizontal.3",
                      remoteID: "inspector.action.advanced") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            ActionRow(label: "Change background…", symbol: "photo",
                      remoteID: "inspector.action.change-background") {
                if let url = pickWallpaperURL() {
                    vm.changeBackground(displayID: tile.displayID, to: url)
                }
            }
        }
    }

    /// Modal NSOpenPanel restricted to image files. Returns the chosen
    /// URL or nil if the user cancelled. Pure picker — the change is
    /// applied separately via `vm.changeBackground(displayID:to:)`.
    /// In hermetic headless tests, the WDMMacRemoteRunner registry
    /// click bypasses this picker entirely (env-driven URL).
    private func pickWallpaperURL() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]
        return panel.runModal() == .OK ? panel.url : nil
    }
}
