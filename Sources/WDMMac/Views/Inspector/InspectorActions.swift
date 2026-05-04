import SwiftUI

/// ACTIONS section — five rows. Each row uses the shared `ActionRow`
/// primitive so the design and remoteID convention stay consistent.
public struct InspectorActions: View {
    public init() {}
    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ActionRow(label: "Make main", symbol: "star",
                      remoteID: "inspector.action.makeMain")
            ActionRow(label: "Open PiP window", symbol: "pip",
                      remoteID: "inspector.action.pip")
            ActionRow(label: "Record", symbol: "record.circle",
                      remoteID: "inspector.action.record")
            ActionRow(label: "Reset / reconnect…", symbol: "arrow.clockwise",
                      remoteID: "inspector.action.reset")
            ActionRow(label: "Open Advanced", symbol: "slider.horizontal.3",
                      remoteID: "inspector.action.advanced")
        }
    }
}
