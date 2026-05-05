import SwiftUI

/// Inspector ACTIONS row — leading SF Symbol, label, optional trailing.
/// Tappable, no chrome (sits inside an inset container).
public struct ActionRow: View {
    let label: String
    let symbol: String
    let remoteID: String
    let action: () -> Void

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
        }
        .buttonStyle(.plain)
        .clickable(cornerRadius: 6)
        .accessibilityIdentifier(remoteID)
    }
}
