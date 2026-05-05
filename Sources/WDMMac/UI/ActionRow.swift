import SwiftUI

/// Inspector ACTIONS row — leading SF Symbol, label, optional trailing.
/// Subtle hover-only chrome to match the design briefing's lighter
/// aesthetic (consistent with `SidebarProfileRow` and
/// `SegmentedRowSegment`):
///   - idle:  no border, transparent — clean
///   - hover: .secondary 10% fill
public struct ActionRow: View {
    let label: String
    let symbol: String
    let remoteID: String
    let action: () -> Void
    @State private var hovering = false

    public init(label: String, symbol: String, remoteID: String,
                action: @escaping () -> Void = {}) {
        self.label = label; self.symbol = symbol
        self.remoteID = remoteID; self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: symbol).font(.system(size: 12))
                    .foregroundStyle(.secondary).frame(width: 18)
                Text(label).font(.system(size: 12, weight: .medium))
                Spacer()
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(hovering ? Color.secondary.opacity(0.10) : .clear)
            }
            // CLAUDE.md responsiveness pillar — snap, don't fade.
            .animation(.easeOut(duration: 0.05), value: hovering)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(remoteID)
        .onHover { hovering = $0 }
    }
}
