import SwiftUI

/// Horizontal row of equal-width segmented buttons. Used by the GEOMETRY
/// rotation row (0/90/180/270) and the flip row (—/Flip H/Flip V).
///
/// Visual treatment matches the design briefing's lighter aesthetic
/// (consistent with `SidebarProfileRow`):
///   - idle:     no border, transparent background — clean look
///   - hover:    subtle .secondary 10% fill
///   - selected: .green 18% fill + 1.5pt green stroke (the existing
///               highlight, kept so workshop facilitators can see the
///               active rotation/flip at a glance)
public struct SegmentedRow<Tag: Hashable>: View {
    public struct Segment: Identifiable {
        public let id: Tag
        public let label: String
        public let remoteID: String
        public init(id: Tag, label: String, remoteID: String) {
            self.id = id; self.label = label; self.remoteID = remoteID
        }
    }
    let segments: [Segment]
    let selected: Tag?
    let onPick: (Tag) -> Void

    public init(segments: [Segment], selected: Tag?, onPick: @escaping (Tag) -> Void) {
        self.segments = segments
        self.selected = selected
        self.onPick = onPick
    }

    public var body: some View {
        HStack(spacing: 6) {
            ForEach(segments) { seg in
                SegmentedRowSegment(
                    label: seg.label,
                    remoteID: seg.remoteID,
                    isSelected: seg.id == selected,
                    onTap: { onPick(seg.id) }
                )
            }
        }
    }
}

private struct SegmentedRowSegment: View {
    let label: String
    let remoteID: String
    let isSelected: Bool
    let onTap: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isSelected ? .green : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background {
                    let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
                    shape.fill(fillColor)
                    shape.stroke(strokeColor, lineWidth: isSelected ? 1.5 : 0)
                }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(remoteID)
        .onHover { hovering = $0 }
    }

    private var fillColor: Color {
        if isSelected { return .green.opacity(0.18) }
        if hovering   { return .secondary.opacity(0.10) }
        return .clear
    }

    private var strokeColor: Color {
        isSelected ? .green : .clear
    }
}
