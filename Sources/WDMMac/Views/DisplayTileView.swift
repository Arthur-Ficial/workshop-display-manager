import SwiftUI

/// One row in the displays list. Pure render — name, mode, "MAIN" badge,
/// selection ring. The view emits `onSelect()`; everything else is the
/// runner's job.
public struct DisplayTileView: View {
    let title: String
    let subtitle: String
    let isMain: Bool
    let isSelected: Bool
    let remoteID: String
    let onSelect: () -> Void

    public init(title: String, subtitle: String, isMain: Bool,
                isSelected: Bool, remoteID: String, onSelect: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.isMain = isMain
        self.isSelected = isSelected
        self.remoteID = remoteID
        self.onSelect = onSelect
    }

    public var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                tileChassis
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title).font(.headline)
                        if isMain {
                            Text("MAIN")
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(.tint.opacity(0.18))
                                .foregroundStyle(.tint)
                                .clipShape(Capsule())
                        }
                    }
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
        }
        .liquidGlassButton()
        .accessibilityIdentifier(remoteID)
    }

    private var tileChassis: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(.quaternary)
                .frame(width: 60, height: 38)
            Image(systemName: isMain ? "laptopcomputer" : "display")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(.secondary)
        }
    }
}
