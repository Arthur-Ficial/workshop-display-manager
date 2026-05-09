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
    let isSelected: (Tag) -> Bool
    let onPick: (Tag) -> Void

    /// Radio-style: exactly one tag is selected at a time (or none).
    public init(segments: [Segment], selected: Tag?, onPick: @escaping (Tag) -> Void) {
        self.segments = segments
        self.isSelected = { $0 == selected }
        self.onPick = onPick
    }

    /// Multi-select: caller decides per-segment which are lit. Used by
    /// the GEOMETRY flip row where Flip H and Flip V are combinable
    /// toggles and "—" lights up when neither is on.
    public init(segments: [Segment], isSelected: @escaping (Tag) -> Bool, onPick: @escaping (Tag) -> Void) {
        self.segments = segments
        self.isSelected = isSelected
        self.onPick = onPick
    }

    public var body: some View {
        HStack(spacing: 6) {
            ForEach(segments) { seg in
                SegmentedRowSegment(
                    label: seg.label,
                    remoteID: seg.remoteID,
                    isSelected: isSelected(seg.id),
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
                .contentShape(Rectangle())
                // Per CLAUDE.md "SUPER RESPONSIVE INTERACTION":
                // selection feedback must land in ≤50 ms. SwiftUI's
                // default cross-fade on background changes is ~250 ms
                // — that's the user-reported "sluggish" feel. Snap.
                .animation(.easeOut(duration: 0.05), value: isSelected)
                .animation(.easeOut(duration: 0.05), value: hovering)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(remoteID)
        // .buttonStyle(.plain) drops default AX press routing; without
        // this, the AXPress reaches the button but never invokes the
        // action closure. Explicit accessibilityAction restores it.
        .accessibilityAction { onTap() }
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
