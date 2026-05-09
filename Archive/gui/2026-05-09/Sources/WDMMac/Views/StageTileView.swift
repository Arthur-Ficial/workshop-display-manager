import SwiftUI

/// One chassis-shaped tile on the Stage canvas. Laptop silhouette for
/// the built-in display, external monitor silhouette for everything else.
/// Selection ring + corner badge ("01", "02", …) match the design briefing.
public struct StageTileView: View {
    let title: String
    let subtitle: String
    let badge: String
    let isSelected: Bool
    let kind: ChassisKind
    let remoteID: String
    let onSelect: () -> Void

    public init(title: String, subtitle: String, badge: String,
                isSelected: Bool, kind: ChassisKind, remoteID: String,
                onSelect: @escaping () -> Void) {
        self.title = title; self.subtitle = subtitle; self.badge = badge
        self.isSelected = isSelected; self.kind = kind
        self.remoteID = remoteID; self.onSelect = onSelect
    }

    public var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .topLeading) {
                // chassis fill + outline
                ChassisShape(kind: kind)
                    .fill(.black.opacity(0.45))
                    .overlay {
                        ChassisShape(kind: kind)
                            .stroke(isSelected ? Color.green : Color.white.opacity(0.18),
                                    lineWidth: isSelected ? 2.5 : 1)
                    }

                // badge top-left over the screen area
                Text(badge)
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background { Capsule().fill(.green.opacity(0.22)) }
                    .foregroundStyle(.green)
                    .padding(8)

                // dims centred on the screen area (which is the top ~80% of the chassis)
                VStack {
                    Spacer()
                    VStack(spacing: 2) {
                        Text(title)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1)
                        Text(subtitle)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .padding(.bottom, 36)  // leave room for the chassis foot/base
                }
            }
            .frame(width: 180, height: 140)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(remoteID)
    }
}
