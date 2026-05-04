import Foundation
import SwiftUI
import WDMCore
import WDMKit

/// View-model for the displays list. Strictly thin: pulls data from
/// `WDMController.list()` (the lib), pushes elements into a registry-shaped
/// `RemoteEntry` array (decoupled from `WDMRemoteControl` so this lib stays
/// dependency-clean), and tracks the currently-selected `remoteID`.
///
/// Render-layer rule: no business logic here — just shaping data for the
/// view + dispatching selection back through a closure that the runner wires
/// to the registry.
@MainActor
public final class DisplaysListVM: ObservableObject {
    public struct Tile: Identifiable, Equatable, Sendable {
        public let remoteID: String
        public let displayID: UInt32
        public let title: String
        public let subtitle: String
        public let isMain: Bool
        public var isSelected: Bool

        public var id: String { remoteID }
    }

    @Published public private(set) var tiles: [Tile] = []
    @Published public private(set) var selectedRemoteID: String?
    @Published public private(set) var lastError: String?

    private let controller: WDMController

    public init(controller: WDMController) {
        self.controller = controller
    }

    public func reload() {
        do {
            let displays = try controller.list()
            tiles = displays.map { d in
                Tile(
                    remoteID: "displays.tile.\(d.id)",
                    displayID: d.id,
                    title: d.name ?? "Display \(d.id)",
                    subtitle: "\(d.currentMode.width)×\(d.currentMode.height) @ \(Int(d.currentMode.refreshHz))Hz",
                    isMain: d.isMain,
                    isSelected: false
                )
            }
            lastError = nil
        } catch {
            lastError = "\(error)"
            tiles = []
        }
    }

    public func select(remoteID: String) {
        selectedRemoteID = remoteID
        tiles = tiles.map { t in
            var copy = t
            copy.isSelected = (t.remoteID == remoteID)
            return copy
        }
    }
}
