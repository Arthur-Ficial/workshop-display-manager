import SwiftUI

/// Placeholder pane for the Advanced tab. Real content (Kit gap-fills,
/// remote-API token controls, daemon settings) lands in later milestones.
public struct AdvancedPane: View {
    public init() {}
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("ADVANCED")
            Text("Daemon, remote-API token, and developer options will land here in a later milestone.")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityIdentifier("settings.pane.advanced")
    }
}
